--[[============================================================================
PakettiStemSlicer.lua
============================================================================]]--

--[[
PakettiStemSlicer - Slice stems into BPM-synced beat chunks

This tool takes a folder of wavefiles and slices them into beat-synchronized chunks
based on a user-specified BPM. It creates slices of 4, 8, 16, 32, and 64 beats,
exports them with proper naming conventions, and detects silent sections.

Main features:
- Folder-based batch processing of wavefiles
- BPM-based beat calculation and slicing
- Multiple beat length options (4, 8, 16, 32, 64)
- Automatic silence detection and marking
- Progress tracking with ProcessSlicer for UI responsiveness
- Proper naming convention: originalname_XXbeats_sliceYY.wav
]]

local vb = renoise.ViewBuilder()
local dialog = nil
local process_slicer = nil

-- Configuration
local ALL_BEAT_LENGTHS = {1, 2, 4, 8, 16, 32, 64}
local SILENCE_THRESHOLD = 0.001 -- RMS threshold for silence detection
local SUPPORTED_FORMATS = {"*.wav", "*.aif", "*.aiff", "*.flac"}

-- User-configurable options
local master_beat_length = 64  -- The base slice size to create first
local extract_beat_lengths = {32, 16, 8, 4, 2, 1}  -- Which subdivisions to extract
local skip_writing_silence = false  -- When true, don't write silence files at all

-- State variables
local selected_folder = ""
local target_bpm = 120 -- Safe default; will sync from transport when dialog opens
local audio_files = {}
local current_progress = ""
local last_output_folder = ""
local last_selected_folder = ""
local last_bpm_used = 0
local last_master_beat = 64
local last_subdivisions = {}

-- Direct to Instruments mode (skip WAV export)
local direct_to_instruments = false
local direct_grouping_mode = 1  -- 1=Per-sample, 2=Per-stem, 3=Per-beat, 4=All combined
local direct_mode_instruments = {}  -- Track instruments created in direct mode
local direct_mode_used = false  -- Track if direct mode was used in last processing

-- Silence file optimization
local silence_files_cache = {} -- Cache for generated silence files per beat length

-- Progress tracking (OPTIMIZATION)
local files_completed = 0
local total_files_to_process = 0
local current_sample_name = "Initializing..."

-- Error tracking and recovery (OPTIMIZATION)
local processing_errors = {}
local files_skipped = 0
local critical_errors = 0
local consecutive_errors = 0 -- Circuit breaker for infinite error loops

-- Memory leak prevention (CRITICAL)
local processing_start_time_absolute = 0
local last_memory_check = 0
local exports_completed = 0

-- EMERGENCY: Dialog flooding prevention
local dialog_spawn_count = 0
local last_dialog_spawn_time = 0
local processing_is_complete = false
local completion_handled = false -- Prevent multiple completion handlers

-- CRITICAL: Global cancellation flag that persists after dialog closes
local processing_cancelled = false

-- Global reusable export instrument to prevent crashes (CRASH PREVENTION)
local export_instrument_idx = nil

-- Calculate beat duration in frames for given BPM and sample rate (EARLY ACCESS)
function calculateBeatDurationFrames(bpm, sample_rate)
    return math.floor((60.0 / bpm) * sample_rate)
end

-- Create reusable export instrument once per session
function createExportInstrument()
    local song = renoise.song()
    
    -- CRITICAL FIX: Always validate existing export instrument by NAME, not just index
    if export_instrument_idx and export_instrument_idx <= #song.instruments then
        local inst = song.instruments[export_instrument_idx]
        -- SAFETY CHECK: Ensure we're looking at the right instrument by name
        if inst and inst.name == "PakettiStemSlicer_Export_Temp" and #inst.samples > 0 then
            print("EXPORT INSTRUMENT: Reusing existing valid export instrument at index", export_instrument_idx)
            return export_instrument_idx
        else
            print("EXPORT INSTRUMENT: Index points to wrong instrument:", inst and inst.name or "nil")
            export_instrument_idx = nil -- Reset to force recreation
        end
    end
    
    -- Look for existing export instrument by name across all instruments
    for i = 1, #song.instruments do
        local inst = song.instruments[i]
        if inst and inst.name == "PakettiStemSlicer_Export_Temp" then
            print("EXPORT INSTRUMENT: Found existing export instrument by name at index", i)
            export_instrument_idx = i
            return export_instrument_idx
        end
    end
    
    -- Create new export instrument at the END of the instrument list
    export_instrument_idx = #song.instruments + 1
    if not safeInsertInstrumentAt(song, export_instrument_idx) then return nil end
    local export_inst = song.instruments[export_instrument_idx]
    export_inst.name = "PakettiStemSlicer_Export_Temp"
    
    if #export_inst.samples == 0 then
        export_inst:insert_sample_at(1)
    end
    
    print("EXPORT INSTRUMENT: Created new export instrument at index", export_instrument_idx)
    return export_instrument_idx
end

-- Clean up export instrument at end of session (ENHANCED LOGGING)
function cleanupExportInstrument()
    if export_instrument_idx then
        local song = renoise.song()
        print(string.format("CLEANUP: Attempting to delete export instrument at index %d (total instruments: %d)", 
            export_instrument_idx, #song.instruments))
        
        if export_instrument_idx <= #song.instruments then
            local inst = song.instruments[export_instrument_idx]
            print(string.format("CLEANUP: Found instrument '%s' at index %d", inst.name, export_instrument_idx))
            
            -- CRITICAL SAFETY CHECK: Only delete if it's actually the export instrument
            if inst.name == "PakettiStemSlicer_Export_Temp" then
                song:delete_instrument_at(export_instrument_idx)
                print("CLEANUP: Successfully deleted export instrument")
            else
                print(string.format("CLEANUP: SAFETY ABORT - Instrument name '%s' doesn't match expected 'PakettiStemSlicer_Export_Temp'", inst.name))
                -- Search for the real export instrument by name
                for i = 1, #song.instruments do
                    local search_inst = song.instruments[i]
                    if search_inst and search_inst.name == "PakettiStemSlicer_Export_Temp" then
                        print(string.format("CLEANUP: Found real export instrument at index %d, deleting that instead", i))
                        song:delete_instrument_at(i)
                        break
                    end
                end
            end
        else
            print(string.format("CLEANUP: Export instrument index %d is out of range (max: %d)", 
                export_instrument_idx, #song.instruments))
        end
        export_instrument_idx = nil
    else
        print("CLEANUP: No export instrument to clean up (export_instrument_idx is nil)")
    end
end

-- Simple dialog prevention (non-aggressive)
function preventDialogFlooding(dialog_type)
    local current_time = os.clock()
    
    -- CRITICAL: Prevent dialog flooding during cancellation/completion
    if processing_is_complete then
        print("FLOOD PREVENTION: Processing already complete, blocking dialog:", dialog_type)
        return false
    end
    
    -- Rate limiting: Don't allow more than one dialog per second of same type
    if last_dialog_spawn_time and (current_time - last_dialog_spawn_time) < 1.0 then
        print("FLOOD PREVENTION: Rate limiting dialog:", dialog_type, "time since last:", current_time - last_dialog_spawn_time)
        return false
    end
    
    -- Count limiting: Don't allow more than 3 dialogs total per session
    dialog_spawn_count = dialog_spawn_count + 1
    if dialog_spawn_count > 3 then
        print("FLOOD PREVENTION: Too many dialogs spawned:", dialog_spawn_count, "blocking:", dialog_type)
        return false
    end
    
    last_dialog_spawn_time = current_time
    print("FLOOD PREVENTION: Allowing dialog:", dialog_type, "count:", dialog_spawn_count)
    return true
end

-- Mark processing as complete
function markProcessingComplete()
    processing_is_complete = true
    print("PROCESSING MARKED AS COMPLETE - No more dialogs should spawn")
end

-- CRITICAL: Cancellation flag management
function markProcessingCancelled()
    processing_cancelled = true
    processing_is_complete = true  -- Also mark as complete to prevent dialogs
    print("PROCESSING CANCELLED - All operations should stop immediately")
end

function isProcessingCancelled()
    return processing_cancelled
end

function resetProcessingCancellation()
    processing_cancelled = false
    print("CANCELLATION FLAG RESET - Ready for new processing session")
end

-- Emergency stop (disabled to avoid annoyance)
function emergencyStopAllDialogs()
    -- Disabled - was too aggressive and annoying
    print("Emergency stop requested but disabled")
end

-- Return to original dialog with completion status (FIXED: No new dialog)
function returnToOriginalDialogWithCompletion()
    -- EMERGENCY: Prevent dialog flooding
    if not preventDialogFlooding("return_to_original") then
        print("EMERGENCY: Blocked return to original dialog due to flooding")
        return -- Don't show dialog
    end
    
    -- If the original dialog is still open, update it with completion info
    if dialog and dialog.visible and vb and vb.views then
        print("UPDATING: Existing dialog with completion status")
        
        -- Update folder display to show completion status with clickable access
        if vb.views.folder_display then
            local completion_text = string.format("COMPLETED: %d files processed", files_completed)
            if files_skipped > 0 then
                completion_text = completion_text .. string.format(" (%d skipped)", files_skipped)
            end
            
            if direct_mode_used then
                -- Direct mode completion message
                completion_text = completion_text .. string.format("\nDIRECT MODE: %d instruments created", #direct_mode_instruments)
            else
                -- Normal mode completion message
                completion_text = completion_text .. string.format("\nOUTPUT: %s", last_output_folder or "Unknown")
            end
            vb.views.folder_display.text = completion_text
            vb.views.folder_display.style = "strong" -- Make it prominent
        end
        
        -- Update status message based on mode
        if direct_mode_used then
            renoise.app():show_status(string.format("PakettiStemSlicer COMPLETE! Direct mode created %d instruments", #direct_mode_instruments))
        elseif last_output_folder then
            print("REPURPOSING: Browse button to Open Output")
            -- We can't change button text in ViewBuilder, but we can update the status
            renoise.app():show_status("PakettiStemSlicer COMPLETE! Check the folder display above for results location")
        end
        
        -- Update BPM display to show what was used
        if vb.views.bpm_input and last_bpm_used then
            vb.views.bpm_input.value = last_bpm_used
        end
        
        print("UPDATED: Original dialog with completion info")
    else
        -- Fallback: Show summary dialog only if original dialog isn't available
        print("FALLBACK: Original dialog not available, showing summary")
        showStemSlicerSummary()
    end
end

-- Convenient function to open the last output folder
function openLastStemSlicerOutput()
    if last_output_folder and last_output_folder ~= "" then
        print("OPENING: Last StemSlicer output folder:", last_output_folder)
        openFolderInFinder(last_output_folder)
        renoise.app():show_status("Opened: " .. last_output_folder)
    else
        renoise.app():show_status("No StemSlicer output folder available")
    end
end

-- Memory monitoring and leak prevention
function checkMemoryUsage()
    exports_completed = exports_completed + 1
    local current_time = os.clock()
    
    -- Check every 10 exports or every 30 seconds
    if exports_completed % 10 == 0 or (current_time - last_memory_check) > 30 then
        last_memory_check = current_time
        local elapsed = current_time - processing_start_time_absolute
        
        -- Force garbage collection to prevent memory accumulation
        collectgarbage("collect")
        
        print(string.format("MEMORY CHECK: %d exports completed in %.1f seconds (%.1f exports/sec)", 
            exports_completed, elapsed, exports_completed / math.max(elapsed, 1)))
        
        -- Safety timeout - if processing takes more than 2 hours, something is wrong
        if elapsed > 7200 then -- 2 hours
            logProcessingError("CRITICAL", "", "Processing timeout - exceeded 2 hours, possible infinite loop")
            return false
        end
        
        -- Safety check - if too many exports, something is wrong
        if exports_completed > 50000 then -- 50k exports is way too many
            logProcessingError("CRITICAL", "", "Too many exports - possible infinite loop, stopping")
            return false
        end
    end
    return true
end

-- Reset memory tracking for new session
function resetMemoryTracking()
    processing_start_time_absolute = os.clock()
    last_memory_check = processing_start_time_absolute
    exports_completed = 0
    collectgarbage("collect") -- Clean start
end

-- Log error with context for debugging and recovery (WITH CIRCUIT BREAKER)
function logProcessingError(error_type, file_path, details)
    consecutive_errors = consecutive_errors + 1
    
    -- CIRCUIT BREAKER: Stop infinite error flooding (threshold increased from 5 to 20 for batch processing)
    if consecutive_errors > 20 then
        print("CIRCUIT BREAKER: Too many consecutive errors (" .. consecutive_errors .. "), stopping to prevent dialog flooding")
        error("CIRCUIT_BREAKER_TRIGGERED: Stopping processing to prevent infinite error dialogs")
    end
    
    local error_entry = {
        type = error_type,
        file = file_path or "unknown",
        details = details or "no details",
        timestamp = os.date("%H:%M:%S")
    }
    table.insert(processing_errors, error_entry)
    print(string.format("ERROR [%s]: %s - %s (%s)", error_type, error_entry.file, details, error_entry.timestamp))
    
    if error_type == "CRITICAL" then
        critical_errors = critical_errors + 1
    else
        files_skipped = files_skipped + 1
    end
end

-- Reset consecutive error counter on successful operation
function resetConsecutiveErrors()
    consecutive_errors = 0
end


-- Clear error tracking for new processing session
function clearErrorTracking()
    processing_errors = {}
    files_skipped = 0
    critical_errors = 0
    consecutive_errors = 0 -- Reset circuit breaker
    completion_handled = false -- Reset completion handler flag
    processing_is_complete = false -- Reset completion flag
    dialog_spawn_count = 0 -- Reset dialog counter
    last_dialog_spawn_time = 0 -- Reset dialog timing
    current_sample_name = "Ready to start..." -- Reset sample display
    resetProcessingCancellation() -- Reset global cancellation flag
end

-- Reset dialog flood prevention state for new session
function resetDialogFloodPrevention()
    dialog_spawn_count = 0
    last_dialog_spawn_time = 0
    processing_is_complete = false
    completion_handled = false
    print("FLOOD PREVENTION: State reset for new session")
end

-- Generate error summary for final report
function generateErrorSummary()
    if #processing_errors == 0 then
        return "No errors encountered during processing."
    end
    
    local summary = string.format("Processing completed with %d errors (%d files skipped):\n", #processing_errors, files_skipped)
    for i, err in ipairs(processing_errors) do
        if i <= 10 then  -- Show first 10 errors
            summary = summary .. string.format("- [%s] %s: %s\n", err.type, err.file:match("[^/\\]+$") or err.file, err.details)
        elseif i == 11 then
            summary = summary .. string.format("... and %d more errors (check console for full log)\n", #processing_errors - 10)
            break
        end
    end
    return summary
end

-- Show current sample being processed
function calculateProgress()
    if total_files_to_process == 0 then
        return current_progress
    end
    
    local current_file_num = files_completed + 1
    if files_completed >= total_files_to_process then
        current_file_num = total_files_to_process
    end
    
    return string.format("Processing Sample: %s (%d/%d)", current_sample_name, current_file_num, total_files_to_process)
end

-- Generate a silence file for a specific beat length and sample rate
function generateSilenceFile(beat_length, sample_rate, output_folder)
  local cache_key = string.format("%d_%d_wav", beat_length, sample_rate)
  if silence_files_cache[cache_key] then
    return silence_files_cache[cache_key]
  end

  local beat_duration_frames = calculateBeatDurationFrames(target_bpm, sample_rate)
  local silence_frames = beat_duration_frames * beat_length
  
  -- CRITICAL SAFETY CHECK: Prevent massive silence file allocations
  if silence_frames > 50000000 then -- 50M frames = ~17 minutes at 48kHz
    error(string.format("Silence file too large: %d frames (%.1f minutes) - possible BPM calculation error", 
        silence_frames, silence_frames / sample_rate / 60))
  end
  
  -- Use reusable export instrument for silence generation (CRASH PREVENTION)
  local export_idx = createExportInstrument()
  local song = renoise.song()
  local export_inst = song.instruments[export_idx]
  local temp_sample = export_inst.samples[1]
  
  -- Create silent sample buffer
  temp_sample.sample_buffer:create_sample_data(sample_rate, 16, 2, silence_frames)
  temp_sample.sample_buffer:prepare_sample_data_changes()
  
  -- Fill with silence (zeros) with SAFE bounds checking (MEMORY LEAK FIX)
  local frames_per_yield = 44100 -- Yield every second of audio
  local max_silence_frames = math.min(silence_frames, 10000000) -- SAFETY: Never more than 10M frames
  
  if max_silence_frames > 5000000 then -- 5M frames = ~1.7 minutes at 48kHz
    print("WARNING: Very large silence file requested:", max_silence_frames, "frames")
  end
  
  for ch = 1, 2 do -- Stereo only
    for frame = 1, max_silence_frames do
      temp_sample.sample_buffer:set_sample_data(ch, frame, 0.0)
      
      -- Yield periodically for ProcessSlicer
      if frame % frames_per_yield == 0 then
        coroutine.yield()
      end
      
      -- SAFETY BREAK - prevent infinite loops
      if frame > silence_frames then
        print("WARNING: Silence generation safety break triggered")
        break
      end
    end
  end
  
  temp_sample.sample_buffer:finalize_sample_data_changes()
  
  -- Export the silence file (ALWAYS as WAV - Renoise only supports wav/flac export)
  local silence_filename = string.format("silence_%02dbeats.wav", beat_length)
  local silence_path = output_folder .. "/" .. silence_filename
  temp_sample.sample_buffer:save_as(silence_path, "wav")
  
  -- Reset consecutive error counter on successful silence generation
  resetConsecutiveErrors()
  
  -- Memory leak prevention - check usage after silence generation
  if not checkMemoryUsage() then
    error("Processing timeout detected during silence generation - stopping to prevent system freeze")
  end
  
  -- No deletion - reuse the same export instrument
  
  -- Cache the path
  silence_files_cache[cache_key] = silence_path
  print(string.format("Generated silence file: %s (%d frames)", silence_filename, silence_frames))
  
  return silence_path
end

-- Copy a silence file to a new location instead of re-generating
function copySilenceFile(source_silence_path, target_path)
  local success = pcall(function()
    -- Use OS-specific file copy
    local copy_cmd
    if package.config:sub(1,1) == "\\" then  -- Windows
      copy_cmd = string.format('copy "%s" "%s"', source_silence_path:gsub("/", "\\"), target_path:gsub("/", "\\"))
    else  -- macOS and Linux
      copy_cmd = string.format("cp '%s' '%s'", source_silence_path:gsub("'", "'\\''"), target_path:gsub("'", "'\\''"))
    end
    os.execute(copy_cmd)
  end)
  return success
end

-- Clear silence cache when starting new processing session
function clearSilenceCache()
  silence_files_cache = {}
end


-- BPM observable wiring (keeps the dialog BPM in sync with transport)
local stemslicer_bpm_observer = nil

function updateStemSlicerBpmDisplay()
  local bpm = renoise.song().transport.bpm
  target_bpm = bpm
  if vb and vb.views and vb.views.bpm_input then
    vb.views.bpm_input.value = bpm
  end
end

-- Offer reverse options for the drumkits just created. Runs via ProcessSlicer.
function offerReverseDialogForBuiltDrumkits(tasks)
  -- Infer which beat-length drumkits exist from task titles
  local beats_present = {}
  for _, t in ipairs(tasks) do
    if t.kind == "drumkit" then
      local b = tonumber((t.title or ""):match("%((%d%d) beats%)"))
      if b then beats_present[b] = true end
    end
  end

  local order = {4,8,16,32,64}
  local available = {}
  for _, b in ipairs(order) do if beats_present[b] then table.insert(available, b) end end
  if #available == 0 then return end

  local vb_local = renoise.ViewBuilder()
  local d = nil
  local checks = {}
  local rows = {}
  for _, b in ipairs(available) do
    local id = string.format("rev_%d", b)
    checks[b] = vb_local:checkbox{ id=id, value=false }
    table.insert(rows, vb_local:row{ checks[b], vb_local:text{ text=string.format("Reverse %02d-beat drumkits", b) } })
  end

  local function begin_reverse()
    local selection = {}
    for _, b in ipairs(available) do if checks[b].value then table.insert(selection, b) end end
    d:close()
    if #selection == 0 then return end
    startReverseBuiltDrumkitsProcess(selection)
  end

  local content = vb_local:column{

    vb_local:text{ text="Reverse created drumkits?", style="strong" },
    unpack(rows),
    vb_local:row{
      vb_local:button{ text="Reverse", width=100, notifier=begin_reverse },
      vb_local:button{ text="Cancel", width=80, notifier=function() d:close() end }
    }
  }
  d = renoise.app():show_custom_dialog("Paketti - Reverse Drumkits", content)
end

-- Reverse samples in instruments whose names match selected beat lengths, using ProcessSlicer
function startReverseBuiltDrumkitsProcess(beats_to_reverse)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local beats_set = {}
  for _, b in ipairs(beats_to_reverse) do beats_set[b] = true end

  local function runner()
    local song = renoise.song()
    for i = 1, #song.instruments do
      local inst = song:instrument(i)
      local name = inst.name or ""
      local b = tonumber(name:match("%((%d%d) beats%) drumkit$"))
      if b and beats_set[b] then
        -- Reverse each sample in this instrument via ProcessSlicer-compatible inner loop
        for s = 1, #inst.samples do
          local buf = inst.samples[s].sample_buffer
          if buf and buf.has_sample_data then
            buf:prepare_sample_data_changes()
            local n_ch = buf.number_of_channels
            local n_fr = buf.number_of_frames
            local half = math.floor(n_fr/2)
            for off=0, half-1 do
              local a = 1+off
              local bfr = n_fr-off
              for ch=1, n_ch do
                local tmp = buf:sample_data(ch, a)
                buf:set_sample_data(ch, a, buf:sample_data(ch, bfr))
                buf:set_sample_data(ch, bfr, tmp)
              end
              if off % 41943 == 0 then coroutine.yield() end -- ~100k frames per yield (stereo)
            end
            buf:finalize_sample_data_changes()
            -- Append (Reversed) to sample name once
            local sname = inst.samples[s].name or ""
            if sname == "" then sname = string.format("Sample %d", s) end
            if not sname:find("%s%((Reversed)%)$") and not sname:find("%(Reversed%)$") then
              inst.samples[s].name = sname .. " (Reversed)"
            end
          end
        end
        -- Append (Reversed) to instrument name once
        if name ~= "" and not name:find("%(Reversed%)$") then
          inst.name = name .. " (Reversed)"
        elseif name == "" then
          inst.name = string.format("Instrument %d (Reversed)", i)
        end
      end
      coroutine.yield()
    end
  end
  local slicer = ProcessSlicer(runner)
  slicer:start()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

function setupStemSlicerBpmObservable()
  if stemslicer_bpm_observer and renoise.song().transport.bpm_observable:has_notifier(stemslicer_bpm_observer) then
    return
  end
  stemslicer_bpm_observer = function()
    -- CRITICAL FIX: Only update BPM if NOT currently processing to prevent race conditions
    if not (process_slicer and process_slicer:running()) then
      updateStemSlicerBpmDisplay()
    else
      print("BPM OBSERVER: Blocked during processing to prevent interference")
    end
  end
  renoise.song().transport.bpm_observable:add_notifier(stemslicer_bpm_observer)
  -- Prime UI with current BPM on open
  updateStemSlicerBpmDisplay()
end

function cleanupStemSlicerBpmObservable()
  if stemslicer_bpm_observer and renoise.song().transport.bpm_observable:has_notifier(stemslicer_bpm_observer) then
    renoise.song().transport.bpm_observable:remove_notifier(stemslicer_bpm_observer)
  end
  stemslicer_bpm_observer = nil
end

-- Instrument capacity guard (global, available everywhere)
function canInsertInstruments(count)
  local song = renoise.song()
  local remaining = 255 - #song.instruments
  if remaining < (count or 1) then
    renoise.app():show_status("Instrument limit reached (255). Stopping load.")
    return false
  end
  return true
end

-- Helper function to update extract_beat_lengths based on checkbox states
function updateExtractBeatLengths()
    extract_beat_lengths = {}
    if vb.views.extract_32 and vb.views.extract_32.value and master_beat_length > 32 then
        table.insert(extract_beat_lengths, 32)
    end
    if vb.views.extract_16 and vb.views.extract_16.value and master_beat_length > 16 then
        table.insert(extract_beat_lengths, 16)
    end
    if vb.views.extract_8 and vb.views.extract_8.value and master_beat_length > 8 then
        table.insert(extract_beat_lengths, 8)
    end
    if vb.views.extract_4 and vb.views.extract_4.value and master_beat_length > 4 then
        table.insert(extract_beat_lengths, 4)
    end
    if vb.views.extract_2 and vb.views.extract_2.value and master_beat_length > 2 then
        table.insert(extract_beat_lengths, 2)
    end
    if vb.views.extract_1 and vb.views.extract_1.value and master_beat_length > 1 then
        table.insert(extract_beat_lengths, 1)
    end
    -- Sort from largest to smallest
    table.sort(extract_beat_lengths, function(a, b) return a > b end)
end

-- Summary dialog after processing (WITH EMERGENCY FLOOD PREVENTION)
function showStemSlicerSummary()
  -- EMERGENCY: Prevent dialog flooding
  if not preventDialogFlooding("completion") then
    print("EMERGENCY: Blocked completion dialog due to flooding")
    return -- Don't show dialog
  end
  local vb_local = renoise.ViewBuilder()
  
  -- Build summary lines based on whether direct mode was used
  local summary_lines = {
    string.format("Source folder: %s", last_selected_folder),
    string.format("BPM: %.2f", last_bpm_used),
    string.format("Master: %d beats", last_master_beat)
  }
  
  if direct_mode_used then
    -- Direct mode summary
    local grouping_names = {"Per-sample", "Per-stem", "Per-beat", "All combined"}
    table.insert(summary_lines, string.format("Mode: Direct to Instruments (%s)", grouping_names[direct_grouping_mode] or "Unknown"))
    table.insert(summary_lines, string.format("Instruments created: %d", #direct_mode_instruments))
  else
    -- Normal mode summary
    table.insert(summary_lines, string.format("Output folder: %s", last_output_folder))
  end
  
  if #last_subdivisions > 0 then
    table.insert(summary_lines, string.format("Subdivisions: %s", table.concat(last_subdivisions, ", ")))
  end

  local grouping_items = {"Group by Sample (64→4)", "Group by Beat across Samples"}
  local grouping_mode_index = 1

  -- Add error summary if there were errors
  local error_display = {}
  if #processing_errors > 0 then
    table.insert(error_display, vb_local:text{text = generateErrorSummary(), style = "disabled"})
    table.insert(error_display, vb_local:space{height=4})
  end

  local content
  if direct_mode_used then
    -- Direct mode: No Quick Load buttons needed (instruments already created)
    content = vb_local:column{
      vb_local:text{text = "Processing complete! (Direct Mode)", style = "strong"},
      vb_local:text{text = table.concat(summary_lines, "\n"), style = "normal"},
      unpack(error_display),
      vb_local:space{height=4},
      vb_local:text{text = "Instruments were created directly - no files written to disk.", style = "disabled"},
      vb_local:text{text = string.format("Check your instrument list for %d new instruments.", #direct_mode_instruments), style = "normal"}
    }
  else
    -- Normal mode: Show Quick Load buttons
    if last_output_folder == "" then return end
    content = vb_local:column{
      vb_local:text{text = "Processing complete!", style = "strong"},
      vb_local:text{text = table.concat(summary_lines, "\n"), style = "normal"},
      unpack(error_display),
      vb_local:space{height=1},
      vb_local:row{
        vb_local:text{text = "Grouping:", style = "normal", width = 80},
        vb_local:popup{ id = "grouping_popup", items = grouping_items, value = grouping_mode_index, width = 240 }
      },
      vb_local:space{height=1},
      vb_local:text{text = "Quick Load (per instrument):", style = "strong"},
      vb_local:row{
        vb_local:button{ text = "Load 64", notifier = function() onQuickLoadSlices(last_output_folder, {64}, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load 32", notifier = function() onQuickLoadSlices(last_output_folder, {32}, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load 16", notifier = function() onQuickLoadSlices(last_output_folder, {16}, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load 8",  notifier = function() onQuickLoadSlices(last_output_folder, {8 }, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load 4",  notifier = function() onQuickLoadSlices(last_output_folder, {4 }, vb_local.views.grouping_popup.value) end}
      },
      vb_local:row{
        vb_local:button{ text = "Load 2",  notifier = function() onQuickLoadSlices(last_output_folder, {2 }, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load 1",  notifier = function() onQuickLoadSlices(last_output_folder, {1 }, vb_local.views.grouping_popup.value) end},
        vb_local:button{ text = "Load All", notifier = function() onQuickLoadSlices(last_output_folder, {64,32,16,8,4,2,1}, vb_local.views.grouping_popup.value) end}
      },
      vb_local:space{height=6},
      vb_local:row{
        vb_local:button{ text = "Open Output Folder", notifier = function()
          openFolderInFinder(last_output_folder)
        end},
        vb_local:button{ text = "Load All Non-Silent Slices", notifier = function()
          onQuickLoadSlices(last_output_folder, {64,32,16,8,4,2,1}, vb_local.views.grouping_popup.value)
        end}
      }
    }
  end
  
  local dialog_title = direct_mode_used and "PakettiStemSlicer - Direct Mode Complete" or "PakettiStemSlicer - Finished"
  renoise.app():show_custom_dialog(dialog_title, content)
end

-- Open folder via OS
function openFolderInFinder(path)
  if package.config:sub(1,1) == "\\" then
    os.execute(string.format('start "" "%s"', path:gsub("/", "\\")))
  else
    os.execute(string.format("open '%s'", path:gsub("'", "'\\''")))
  end
end

-- Scan output folder and load non-silent slices grouped into instruments with headers (FIXED SILENCE FILTERING)
function loadNonSilentSlicesIntoInstruments(folder)
  local all_files = PakettiGetFilesInDirectory(folder)
  
  -- CRITICAL FIX: Filter out ALL silence files before processing
  local files = {}
  for _, f in ipairs(all_files) do
    if not isSilentSlicePath(f) then
      table.insert(files, f)
    end
  end
  
  print(string.format("loadNonSilentSlicesIntoInstruments: Filtered %d silence files, processing %d non-silence files", #all_files - #files, #files))
  
  if #files == 0 then
    renoise.app():show_status("No non-silence files found in output folder")
    print("No non-silence files found in output folder:", folder)
    return
  end
  
  -- Files are already filtered, just sort them
  table.sort(files)
  local non_silent = files -- Use filtered files directly

  local song = renoise.song()
  local by_sample_then_beats = {}
  for _, f in ipairs(non_silent) do
    local name = f:match("[^/\\]+$") or f
    local base = name:gsub("_%d%dbeats.*$", "")
    local beats = tonumber(name:match("_(%d%d)beats")) or 0
    by_sample_then_beats[base] = by_sample_then_beats[base] or {}
    by_sample_then_beats[base][beats] = by_sample_then_beats[base][beats] or {}
    table.insert(by_sample_then_beats[base][beats], f)
  end

  local function insert_header_instrument(title)
    local idx = song.selected_instrument_index + 1
    if not safeInsertInstrumentAt(song, idx) then return nil end
    song.selected_instrument_index = idx
    pakettiPreferencesDefaultInstrumentLoader()
    local inst = song:instrument(idx)
    inst.name = title
    return idx
  end

  -- Load grouped: per sample -> descending beats
  for sample_base, beats_table in pairs(by_sample_then_beats) do
    insert_header_instrument(string.format("== %s =", sample_base))
    local ordered_beats = {64,32,16,8,4,2,1}
    for _, beats in ipairs(ordered_beats) do
      if beats_table[beats] then
        insert_header_instrument(string.format("== %02d Beats of %s ==", beats, sample_base))
        for _, filepath in ipairs(beats_table[beats]) do
          local next_idx = song.selected_instrument_index + 1
          if not safeInsertInstrumentAt(song, next_idx) then return end
          song.selected_instrument_index = next_idx
          pakettiPreferencesDefaultInstrumentLoader()
          local inst = song:instrument(next_idx)
          inst.name = filepath:match("[^/\\]+$") or filepath
          if #inst.samples == 0 then inst:insert_sample_at(1) end
          song.selected_sample_index = 1
          inst.samples[1].sample_buffer:load_from(filepath)
          renoise.app():show_status("Loaded "..(filepath:match("[^/\\]+$") or filepath))
          coroutine.yield()
        end
      end
    end
  end
end

-- Quick-load handler with grouping and beat filters (EXCLUDES SILENCE FILES)
function onQuickLoadSlices(folder, beats_filter, grouping_mode_index)
  local all_files = PakettiGetFilesInDirectory(folder)
  
  -- FILTER OUT SILENCE FILES - they're useless for drumkits!
  local files = {}
  for _, file in ipairs(all_files) do
    if not isSilentSlicePath(file) then
      table.insert(files, file)
    end
  end
  
  if #files == 0 then
    renoise.app():show_status("No non-silence files to load.")
    return
  end
  
  print(string.format("Filtered out silence files: %d total files, %d non-silence files", #all_files, #files))
  -- Build map: sample_base -> beat -> {files} (silence files already filtered out)
  local map = {}
  for _, f in ipairs(files) do
    local name = f:match("[^/\\]+$") or f
    local base = name:gsub("_%d%dbeats.*$", "")
    local beats = tonumber(name:match("_(%d%d)beats")) or 0
    if beats > 0 then
      map[base] = map[base] or {}
      map[base][beats] = map[base][beats] or {}
      table.insert(map[base][beats], f)
    end
  end
  
  -- Sort files within each beats group by slice number (numerical, not alphabetical)
  for base, beats_tbl in pairs(map) do
    for beats, file_list in pairs(beats_tbl) do
      table.sort(file_list, function(a, b)
        local name_a = a:match("[^/\\]+$") or a
        local name_b = b:match("[^/\\]+$") or b
        local slice_a = tonumber(name_a:match("_slice(%d+)")) or 0
        local slice_b = tonumber(name_b:match("_slice(%d+)")) or 0
        return slice_a < slice_b
      end)
    end
  end

  local ordered_beats = {64,32,16,8,4,2,1}
  local want = {}
  for _, b in ipairs(ordered_beats) do
    for _, wf in ipairs(beats_filter) do if b == wf then table.insert(want, b) end end
  end

  -- Build task list for ProcessSlicer
  local tasks = {}
  if grouping_mode_index == 1 then
    for base, beats_tbl in pairs(map) do
      table.insert(tasks, {kind="header", title=string.format("== %s =", base)})
      for _, b in ipairs(want) do
        if beats_tbl[b] then
          table.insert(tasks, {kind="header", title=string.format("== %02d Beats of %s ==", b, base)})
          for _, f in ipairs(beats_tbl[b]) do if not isSilentSlicePath(f) then table.insert(tasks, {kind="file", path=f}) end end
        end
      end
    end
  else
    for _, b in ipairs(want) do
      table.insert(tasks, {kind="header", title=string.format("== %02d Beats =", b)})
      for base, beats_tbl in pairs(map) do
        if beats_tbl[b] then
          table.insert(tasks, {kind="header", title=string.format("-- %s --", base)})
          for _, f in ipairs(beats_tbl[b]) do if not isSilentSlicePath(f) then table.insert(tasks, {kind="file", path=f}) end end
        end
      end
    end
  end

  startQuickLoadProcess(tasks)
end

-- Build drumkits per beat and combined, skipping silent, respecting 120-zone limit
function loadAsDrumkitsFromFolder(folder)
  local files = PakettiGetFilesInDirectory(folder)
  if #files == 0 then renoise.app():show_status("No files to drumkit-load.") return end

  local per_beat = { [1]={}, [2]={}, [4]={}, [8]={}, [16]={}, [32]={}, [64]={} }
  local per_sample_order = {}

  for _, f in ipairs(files) do
    if not isSilentSlicePath(f) then
      local name = f:match("[^/\\]+$") or f
      local base = name:gsub("_%d%dbeats.*$", "")
      local beats = tonumber(name:match("_(%d%d)beats")) or 0
      if beats > 0 and per_beat[beats] then
        table.insert(per_beat[beats], f)
        if not per_sample_order[base] then per_sample_order[base] = true end
      end
    end
  end

  local ordered_beats = {1,2,4,8,16,32,64}
  local per_beat_tasks = {}
  -- Summary header before all-samples drumkits
  table.insert(per_beat_tasks, {kind="header", title="== All Samples Drumkit (64, 32, 16, 08, 04, 02, 01) =="})
  for _, b in ipairs(ordered_beats) do
    if #per_beat[b] > 0 then
      table.insert(per_beat_tasks, {kind="drumkit", title=string.format("All Samples (%02d beats) drumkit", b), files=per_beat[b], reverse_threshold=0})
    end
  end

  -- Combined drumkit across all beats, grouped by sample then beat order 4->64 per sample
  local combined = {}
  local by_sample = {}
  for _, f in ipairs(files) do
    if not isSilentSlicePath(f) then
      local name = f:match("[^/\\]+$") or f
      local base = name:gsub("_%d%dbeats.*$", "")
      local beats = tonumber(name:match("_(%d%d)beats")) or 0
      if beats > 0 then
        by_sample[base] = by_sample[base] or {}
        by_sample[base][beats] = by_sample[base][beats] or {}
        table.insert(by_sample[base][beats], f)
      end
    end
  end

  -- Per-sample drumkits with naming "filename (NN beats) drumkit"
  for base, beats_tbl in pairs(by_sample) do
    -- Add per-sample header instrument for drumkit grouping
    table.insert(per_beat_tasks, {kind="header", title=string.format("== %s DRUMKIT ==", base)})
    for _, b in ipairs(ordered_beats) do
      if beats_tbl[b] and #beats_tbl[b] > 0 then
        table.insert(per_beat_tasks, {kind="drumkit", title=string.format("%s (%02d beats) drumkit", base, b), files=beats_tbl[b], reverse_threshold=0})
      end
    end
  end

  for base, beats_tbl in pairs(by_sample) do
    for _, b in ipairs(ordered_beats) do
      if beats_tbl[b] then for _, f in ipairs(beats_tbl[b]) do table.insert(combined, f) end end
    end
  end
  if #combined > 0 then table.insert(per_beat_tasks, {kind="drumkit", title="All Samples (all beats) drumkit", files=combined, reverse_threshold=0}) end

  startDrumkitBuildProcess(per_beat_tasks)
end

-- Create one drumkit instrument from file list (up to 120 zones)
function makeDrumkitInstrument(file_list, title, reverse_threshold)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local max_zones = 120
  table.sort(file_list)
  local take = {}
  for i=1, math.min(#file_list, max_zones) do table.insert(take, file_list[i]) end
  if #take == 0 then return end

  -- Load default drumkit template and then fill zones by loading samples into instrument
  local song = renoise.song()
  local idx = song.selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, idx) then return end
  song.selected_instrument_index = idx
  -- Load Paketti default drumkit template to ensure mappings/macros; keep process responsive
  pcall(function()
    local defaultInstrument = preferences and preferences.pakettiDefaultDrumkitXRNI and preferences.pakettiDefaultDrumkitXRNI.value
    if defaultInstrument and defaultInstrument ~= "" then
      renoise.app():load_instrument(defaultInstrument)
    else
      renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
    end
  end)
  local inst = song:instrument(idx)
  inst.name = title
  
  -- Apply modulation settings using helper function
  PakettiApplyLoaderModulationSettings(inst, "PakettiStemSlicer loadAsDrumkitsFromFolder")

  -- Ensure at least one sample
  if #inst.samples == 0 then inst:insert_sample_at(1) end
  -- Fill zones sequentially with proper settings
  local zone_index = 1
  for _, f in ipairs(take) do
    if zone_index == 1 then
      inst.samples[1].sample_buffer:load_from(f)
      local fn = (f:match("[^/\\]+$") or f):gsub("%.%w+$", "")
      inst.samples[1].name = fn
      -- Apply drumkit-specific settings to first sample
      applyStemSlicerDrumkitSettings(inst.samples[1])
    else
      inst:insert_sample_at(zone_index)
      inst.samples[zone_index].sample_buffer:load_from(f)
      local fn = (f:match("[^/\\]+$") or f):gsub("%.%w+$", "")
      inst.samples[zone_index].name = fn
      -- Apply drumkit-specific settings to each sample
      applyStemSlicerDrumkitSettings(inst.samples[zone_index])
    end
    zone_index = zone_index + 1
    if zone_index > max_zones then break end
  end

  -- No auto-reverse here per request; keep ProcessSlicer responsive by avoiding heavy in-place transforms
  finalizeInstrumentPaketti(inst)
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Make-everything workflow
function makeEverythingFromFolder(folder)
  -- 1) Combined drumkits per beats and all-beats combined
  loadAsDrumkitsFromFolder(folder)
  -- 2) Then per-sample instrument groupings using default XRNI, one slice/instrument
  onQuickLoadSlices(folder, {64,32,16,8,4,2,1}, 1)
end

-- ProcessSlicer wrapper for drumkit creation to avoid yield across C boundary
function startDrumkitBuildProcess(tasks)
  local function runner()
    for _, t in ipairs(tasks) do
      if not canInsertInstruments(1) then break end
      if t.kind == "drumkit" then
        makeDrumkitInstrument(t.files, t.title, t.reverse_threshold)
      elseif t.kind == "header" then
        insertHeaderInstrumentForLoader(t.title)
      end
      coroutine.yield()
    end
    -- After building all drumkits, offer optional reverse by beat-length classes that were actually created
    offerReverseDialogForBuiltDrumkits(tasks)
  end
  local slicer = ProcessSlicer(runner)
  slicer:start()
end

function insertHeaderInstrumentForLoader(title)
  local song = renoise.song()
  local idx = song.selected_instrument_index + 1
  if not safeInsertInstrumentAt(song, idx) then return nil end
  song.selected_instrument_index = idx
  
  local inst = song:instrument(idx)
  inst.name = title
  return idx
end

function loadFilesAsInstruments(file_list)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local song = renoise.song()
  table.sort(file_list)
  for _, filepath in ipairs(file_list) do
    local idx = song.selected_instrument_index + 1
    if not safeInsertInstrumentAt(song, idx) then return end
    song.selected_instrument_index = idx
    pakettiPreferencesDefaultInstrumentLoader()
    local inst = song:instrument(idx)
    local filename_only = filepath:match("[^/\\]+$") or filepath
    inst.name = filename_only
    if #inst.samples == 0 then inst:insert_sample_at(1) end
    song.selected_sample_index = 1
    inst.samples[1].sample_buffer:load_from(filepath)
    -- Set sample name to filename without extension
    local sample_name = (filename_only:gsub("%.%w+$", ""))
    inst.samples[1].name = sample_name
  end
  finalizeInstrumentPaketti(song:instrument(song.selected_instrument_index))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Run quick-load tasks inside ProcessSlicer (avoids yield across C boundary)
function startQuickLoadProcess(tasks)
  local function runner()
    for _, t in ipairs(tasks) do
      if t.kind == "header" then
        insertHeaderInstrumentForLoader(t.title)
      elseif t.kind == "file" then
        local song = renoise.song()
        local idx = song.selected_instrument_index + 1
        if not safeInsertInstrumentAt(song, idx) then return end
        song.selected_instrument_index = idx
        pakettiPreferencesDefaultInstrumentLoader()
        local inst = song:instrument(idx)
        inst.name = t.path:match("[^/\\]+$") or t.path
        if #inst.samples == 0 then inst:insert_sample_at(1) end
        song.selected_sample_index = 1
        inst.samples[1].sample_buffer:load_from(t.path)
        -- Set sample name to match filename (without extension)
        local filename = t.path:match("[^/\\]+$") or t.path
        inst.samples[1].name = filename:gsub("%.%w+$", "")  -- Remove file extension
        -- Apply Paketti loader preferences to the loaded sample
        PakettiInjectApplyLoaderSettings(inst.samples[1])
      end
      coroutine.yield()
    end
  end
  local slicer = ProcessSlicer(runner)
  slicer:start()
end
-- Helper function to get supported audio files from folder (ONLY selected folder, no subfolders)
local function getSupportedAudioFiles(folder_path)
    local audio_files = {}
    
    if not folder_path or folder_path == "" then
        return audio_files
    end
    
    -- Get files only from the selected folder (non-recursive)
    local success, files = pcall(os.filenames, folder_path, "*")
    if not success then
        print("Failed to read folder:", folder_path)
        return audio_files
    end
    
    -- Filter for supported audio formats
    local supported_extensions = {"%.wav$", "%.aif$", "%.aiff$", "%.flac$"}
    
    for _, filename in ipairs(files) do
        local full_path = folder_path .. "/" .. filename
        local lower_filename = filename:lower()
        
        -- Check if file has supported audio extension
        for _, ext_pattern in ipairs(supported_extensions) do
            if lower_filename:match(ext_pattern) then
                table.insert(audio_files, full_path)
                break
            end
        end
    end
    
    -- Sort files alphabetically
    table.sort(audio_files)
    
    print(string.format("Found %d audio files in folder: %s", #audio_files, folder_path))
    
    return audio_files
end

-- Helper: compute output folder path for current selection
local function getOutputFolderPath()
  if selected_folder == nil or selected_folder == "" then return "" end
  return selected_folder .. "/PakettiStemSlicer_Output"
end

function isSilentSlicePath(path)
  if not path or path == "" then return false end
  local filename = path:match("[^/\\]+$") or path
  local p = string.lower(filename)
  
  -- COMPREHENSIVE SILENCE DETECTION - catch ALL silence file patterns:
  
  -- 1. Generated silence files (silence_04beats.wav, silence_32beats.wav, etc)
  if p:match("^silence_") then return true end
  
  -- 2. Silence files with beat numbers (silence04beats.wav, silence32beats.wav)
  if p:match("^silence%d+beats") then return true end
  
  -- 3. Files ending with _silence suffix before extension
  if p:match("_silence%.[%w]+$") then return true end
  
  -- 4. Files ending with _silent suffix before extension  
  if p:match("_silent%.[%w]+$") then return true end
  
  -- 5. Files with -silence- or _silence_ in middle
  if p:match("[_%-%s]silence[_%-%s]") then return true end
  
  -- 6. Files that are just "silence" with extension
  if p:match("^silence%.[%w]+$") then return true end
  
  return false
end

-- Instrument capacity guard
local function canInsertInstruments(count)
  local song = renoise.song()
  local remaining = 255 - #song.instruments
  if remaining < count then
    renoise.app():show_status("Instrument limit reached (255). Stopping load.")
    return false
  end
  return true
end

-- Helper: remove any remaining "Placeholder sample" entries from an instrument
function removePlaceholderSamples(instrument)
  if not instrument or not instrument.samples then return end
  for i = #instrument.samples, 1, -1 do
    local s = instrument.samples[i]
    if s and s.name == "Placeholder sample" then
      instrument:delete_sample_at(i)
    end
  end
end

-- Helper: apply Paketti loader settings to an instrument (envelopes/macros)
function applyPakettiLoaderSettings(instrument)
  if not instrument then return end
  instrument.macros_visible = true
  if preferences and preferences.pakettiPitchbendLoaderEnvelope and preferences.pakettiPitchbendLoaderEnvelope.value then
    if instrument.sample_modulation_sets and #instrument.sample_modulation_sets > 0 then
      PakettiApplyLoaderModulationSettings(instrument, "PakettiStemSlicer")
    end
  end
  -- Apply per-sample loader settings
  if instrument.samples then
    for i = 1, #instrument.samples do
      local sample = instrument.samples[i]
      if sample then
        -- Prefer Wipe&Slice prefs for slice-style playback
        if preferences and preferences.WipeSlices then
          local ws = preferences.WipeSlices
          if ws.WipeSlicesAutofade then sample.autofade = ws.WipeSlicesAutofade.value end
          if ws.WipeSlicesAutoseek then sample.autoseek = ws.WipeSlicesAutoseek.value end
          if ws.WipeSlicesLoopMode then sample.loop_mode = ws.WipeSlicesLoopMode.value end
          if ws.WipeSlicesOneShot then sample.oneshot = ws.WipeSlicesOneShot.value end
          if ws.WipeSlicesNNA then sample.new_note_action = ws.WipeSlicesNNA.value end
          if ws.WipeSlicesLoopRelease then sample.loop_release = ws.WipeSlicesLoopRelease.value end
          --if ws.WipeSlicesMuteGroup then sample.mute_group = ws.WipeSlicesMuteGroup.value end
          -- Optional: set half-loop for slices (skip first sample as "original")
          if ws.SliceLoopMode and ws.SliceLoopMode.value and i > 1 then
            local frames = 0
            if sample.sample_buffer and sample.sample_buffer.has_sample_data then
              frames = sample.sample_buffer.number_of_frames
            end
            if frames > 0 then
              sample.loop_start = math.floor(frames / 2)
            end
          end
        else
          -- Fallback to Paketti loader prefs when WipeSlices not available
          if preferences and preferences.pakettiLoaderAutofade then sample.autofade = preferences.pakettiLoaderAutofade.value end
          if preferences and preferences.pakettiLoaderAutoseek then sample.autoseek = preferences.pakettiLoaderAutoseek.value end
          if preferences and preferences.pakettiLoaderLoopMode then sample.loop_mode = preferences.pakettiLoaderLoopMode.value end
          if preferences and preferences.pakettiLoaderInterpolation then sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value end
          if preferences and preferences.pakettiLoaderOverSampling then sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value end
          if preferences and preferences.pakettiLoaderOneshot then sample.oneshot = preferences.pakettiLoaderOneshot.value end
          if preferences and preferences.pakettiLoaderNNA then sample.new_note_action = preferences.pakettiLoaderNNA.value end
          if preferences and preferences.pakettiLoaderLoopExit then sample.loop_release = preferences.pakettiLoaderLoopExit.value end
        end
      end
    end
  end
end

-- Apply drumkit-specific settings for StemSlicer (Cut, oversampling, interpolation)
function applyStemSlicerDrumkitSettings(sample)
  if not sample then return end
  
  -- Set to Cut mode for drumkit-style playback
  sample.new_note_action = 1
  sample.oneshot = true
  
  -- Apply oversampling and interpolation settings from preferences if available
  if preferences then
    if preferences.pakettiLoaderOverSampling then 
      sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value 
    end
    if preferences.pakettiLoaderInterpolation then 
      sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value 
    end
    
    -- Apply additional drumkit-optimized settings
    if preferences.pakettiLoaderLoopMode then 
      sample.loop_mode = renoise.Sample.LOOP_MODE_OFF  -- Force no loop for drumkits
    else
      sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    end
    
    if preferences.pakettiLoaderAutofade then 
      sample.autofade = preferences.pakettiLoaderAutofade.value 
    end
    if preferences.pakettiLoaderAutoseek then 
      sample.autoseek = preferences.pakettiLoaderAutoseek.value 
    end
    if preferences.pakettiLoaderLoopExit then 
      sample.loop_release = preferences.pakettiLoaderLoopExit.value 
    end
  else
    -- Fallback settings when preferences not available
    sample.oversample_enabled = false
    sample.interpolation_mode = renoise.Sample.INTERPOLATE_LINEAR
    sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
    sample.autofade = false
    sample.autoseek = true
    sample.loop_release = false
  end
  
  print(string.format("Applied drumkit settings to sample: %s (Cut=%s, Oversample=%s, Interpolation=%d)", 
    sample.name or "unnamed", 
    tostring(sample.new_note_action == 1),
    tostring(sample.oversample_enabled),
    sample.interpolation_mode))
end

-- Helper: finalize instrument according to Paketti conventions
function finalizeInstrumentPaketti(instrument)
  removePlaceholderSamples(instrument)
  applyPakettiLoaderSettings(instrument)
end

-- Helper function to get clean filename without extension
local function getCleanFilename(filepath)
    local filename = filepath:match("[^/\\]+$")
    if filename then
        return filename:gsub("%.%w+$", "") -- Remove extension
    end
    return "unknown"
end

-- Helper function to get file extension
local function getFileExtension(filepath)
    return filepath:match("%.(%w+)$") or "wav"
end



-- Silence detection chunk size (30k frames as requested)
local SILENCE_CHUNK_SIZE = 30000

-- Global silence map cache per file processing session
local current_silence_map = nil
local current_silence_map_file = ""

-- Create silence map for entire file using 30k frame chunks (HIERARCHICAL OPTIMIZATION)
function createSilenceMapForFile(buffer, file_path)
    -- Return cached map if already computed for this file
    if current_silence_map and current_silence_map_file == file_path then
        return current_silence_map
    end
    
    if not buffer or not buffer.has_sample_data then 
        current_silence_map = {}
        current_silence_map_file = file_path
        return current_silence_map 
    end
    
    local total_frames = buffer.number_of_frames
    local channels = buffer.number_of_channels
    local silence_map = {}
    
    print(string.format("Creating silence map for %s (%d frames in %dk chunks)", 
        file_path:match("[^/\\]+$") or file_path, total_frames, SILENCE_CHUNK_SIZE/1000))
    
    -- Divide file into 30k frame chunks and test each for silence
    local chunk_idx = 1
    local start_frame = 1
    
    while start_frame <= total_frames do
        local end_frame = math.min(start_frame + SILENCE_CHUNK_SIZE - 1, total_frames)
        local chunk_length = end_frame - start_frame + 1
        
        if chunk_length <= 0 then break end
        
        -- Test this 30k chunk for silence with proper sampling
        local is_silent = true
        local max_samples_per_chunk = 3000 -- Sample 3k frames from each 30k chunk
        local step = math.max(1, math.floor(chunk_length / max_samples_per_chunk))
        local total_rms = 0
        local max_abs = 0
        local sample_count = 0
        
        for ch = 1, channels do
            local f = start_frame
            while f <= end_frame and is_silent do
                local v = buffer:sample_data(ch, f)
                local av = math.abs(v)
                if av > max_abs then max_abs = av end
                total_rms = total_rms + (v * v)
                sample_count = sample_count + 1
                
                -- Early exit if we find significant audio
                if av > (SILENCE_THRESHOLD * 4) then
                    is_silent = false
                    break
                end
                
                f = f + step
            end
            if not is_silent then break end
        end
        
        -- Final RMS check if still potentially silent
        if is_silent and sample_count > 0 then
            local rms = math.sqrt(total_rms / sample_count)
            is_silent = (rms < SILENCE_THRESHOLD and max_abs < (SILENCE_THRESHOLD * 4))
        end
        
        silence_map[chunk_idx] = {
            start_frame = start_frame,
            end_frame = end_frame,
            is_silent = is_silent
        }
        
        chunk_idx = chunk_idx + 1
        start_frame = end_frame + 1
        
        -- Yield occasionally during silence map creation
        if chunk_idx % 20 == 0 then
            coroutine.yield()
        end
    end
    
    local silent_chunks = 0
    for _, chunk in ipairs(silence_map) do
        if chunk.is_silent then silent_chunks = silent_chunks + 1 end
    end
    
    print(string.format("Silence map created: %d chunks total, %d silent (%.1f%%)", 
        #silence_map, silent_chunks, (silent_chunks / #silence_map) * 100))
    
    -- Cache the result
    current_silence_map = silence_map
    current_silence_map_file = file_path
    
    return silence_map
end

-- Check if a region is silent using the pre-computed silence map (HIERARCHICAL OPTIMIZATION)
local function checkSilenceUsingMap(start_frame, end_frame, silence_map)
    if not silence_map or #silence_map == 0 then return true end
    
    -- Find all chunks that overlap with this region
    for _, chunk in ipairs(silence_map) do
        -- Check if this chunk overlaps with our region
        local chunk_start = chunk.start_frame
        local chunk_end = chunk.end_frame
        
        -- If any part of our region overlaps with a non-silent chunk, the region is not silent
        if not (end_frame < chunk_start or start_frame > chunk_end) then -- They overlap
            if not chunk.is_silent then
                return false -- Found non-silent chunk in our region
            end
        end
    end
    
    return true -- All overlapping chunks are silent
end

-- Clear silence map when starting new file
function clearSilenceMap()
    current_silence_map = nil
    current_silence_map_file = ""
end

-- Export a specific region of a sample buffer to wav file (CRASH SAFE)
local function exportSliceRegion(buffer, start_frame, end_frame, output_path)
    local success, error_msg = pcall(function()
        -- CRITICAL OFF-BY-ONE PREVENTION: Clamp end_frame to buffer bounds
        end_frame = math.min(end_frame, buffer.number_of_frames)
        start_frame = math.max(start_frame, 1)
        
        local slice_length = end_frame - start_frame + 1
        
        -- CRITICAL SAFETY CHECK: Prevent massive buffer allocations
        if slice_length > 50000000 then -- 50M frames = ~17 minutes at 48kHz
            error(string.format("Slice too large: %d frames (%.1f minutes) - possible calculation error", 
                slice_length, slice_length / 48000 / 60))
        end
        
        if slice_length <= 0 then
            error("Invalid slice length: " .. slice_length)
        end
        
        print(string.format("EXPORT DEBUG: start=%d, end=%d, length=%d, buffer_frames=%d", 
            start_frame, end_frame, slice_length, buffer.number_of_frames))
        
        -- Use reusable export instrument instead of creating new ones
        local export_idx = createExportInstrument()
        local song = renoise.song()
        local export_inst = song.instruments[export_idx]
        local temp_sample = export_inst.samples[1]
        
        -- Create buffer for the slice
        temp_sample.sample_buffer:create_sample_data(
            buffer.sample_rate, 
            buffer.bit_depth, 
            buffer.number_of_channels, 
            slice_length
        )
        
        temp_sample.sample_buffer:prepare_sample_data_changes()
        
        -- Copy the region data with SAFE bounds checking (MEMORY LEAK FIX)
        local frames_per_yield = 44100 -- Yield every second of audio
        local max_frame = math.min(slice_length, 10000000) -- SAFETY: Never more than 10M frames
        
        for ch = 1, math.min(buffer.number_of_channels, 8) do -- SAFETY: Max 8 channels
            for frame = 1, max_frame do
                local source_frame = start_frame + frame - 1
                
                -- CRITICAL OFF-BY-ONE FIX: Ensure we never exceed buffer bounds
                if source_frame >= 1 and source_frame <= math.min(buffer.number_of_frames, end_frame) then
                    temp_sample.sample_buffer:set_sample_data(ch, frame, buffer:sample_data(ch, source_frame))
                else
                    -- Fill with silence if out of bounds (this is normal for final slice)
                    temp_sample.sample_buffer:set_sample_data(ch, frame, 0.0)
                end
                
                -- Yield periodically to keep UI responsive
                if frame % frames_per_yield == 0 then
                    coroutine.yield()
                end
                
                -- SAFETY BREAK - prevent infinite loops
                if frame > slice_length then
                    print("WARNING: Frame loop safety break triggered")
                    break
                end
            end
        end
        
        temp_sample.sample_buffer:finalize_sample_data_changes()
        
        -- Export the slice (ALWAYS as WAV)
        temp_sample.sample_buffer:save_as(output_path, "wav")
        
        -- Reset consecutive error counter on successful export
        resetConsecutiveErrors()
        
        -- Memory leak prevention - check usage after each export
        if not checkMemoryUsage() then
            error("Processing timeout detected - stopping to prevent system freeze")
        end
        
        -- No deletion here - reuse the same instrument
    end)
    
    return success, error_msg or ""
end

-- Export slice as wav file (legacy function, kept for compatibility)
local function exportSlice(slice_sample, output_path)
    local success, error_msg = pcall(function()
        -- Use Renoise's built-in sample export
        slice_sample.sample_buffer:save_as(output_path, "wav")
    end)
    
    return success, error_msg or ""
end

-- Direct mode instrument tracking (reset at start of each processing session)
local direct_mode_stem_instruments = {}  -- stem_name -> instrument_index
local direct_mode_beat_instruments = {}  -- beat_length -> instrument_index
local direct_mode_combined_instrument = nil  -- Single instrument index for "All combined" mode
local direct_mode_combined_sample_count = 0  -- Track samples in combined mode (max 120)

-- Reset direct mode tracking (call at start of processing)
local function resetDirectModeTracking()
    direct_mode_stem_instruments = {}
    direct_mode_beat_instruments = {}
    direct_mode_combined_instrument = nil
    direct_mode_combined_sample_count = 0
    direct_mode_instruments = {}
    print("DIRECT MODE: Reset tracking variables")
end

-- Helper function to check if a slice region is silent (RMS-based)
local function isSliceRegionSilent(buffer, start_frame, end_frame)
    local channels = buffer.number_of_channels
    local total_frames = buffer.number_of_frames
    
    -- Clamp to valid range
    start_frame = math.max(1, start_frame)
    end_frame = math.min(end_frame, total_frames)
    
    local slice_length = end_frame - start_frame + 1
    if slice_length <= 0 then return true end
    
    -- Sample every Nth frame to speed up detection
    local max_samples = 1000
    local step = math.max(1, math.floor(slice_length / max_samples))
    local total_rms = 0
    local max_abs = 0
    local sample_count = 0
    
    for ch = 1, channels do
        local f = start_frame
        while f <= end_frame do
            local v = buffer:sample_data(ch, f)
            local av = math.abs(v)
            if av > max_abs then max_abs = av end
            total_rms = total_rms + (v * v)
            sample_count = sample_count + 1
            
            -- Early exit if we find significant audio
            if av > (SILENCE_THRESHOLD * 4) then
                return false  -- Not silent
            end
            
            f = f + step
        end
    end
    
    -- Final RMS check
    if sample_count > 0 then
        local rms = math.sqrt(total_rms / sample_count)
        return (rms < SILENCE_THRESHOLD and max_abs < (SILENCE_THRESHOLD * 4))
    end
    
    return true  -- Empty or invalid = silent
end

-- OPTIMIZED DIRECT MODE: Create DRUMKIT instruments with slices mapped to separate keys
-- Each beat length creates one drumkit instrument where slices are mapped to different notes
-- SKIPS SILENT SLICES - only non-silent audio becomes samples
local function processFileWithNativeSlicing(file_path, beat_lengths_to_process, bpm)
    local song = renoise.song()
    local stem_name = file_path:match("[^/\\]+$"):gsub("%.%w+$", "")
    
    print(string.format("DRUMKIT SLICING: Processing %s at %d BPM", stem_name, bpm))
    
    -- Temporarily disable AutoSamplify monitoring to prevent interference
    local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
    
    -- 1. Create temporary instrument and load audio
    local source_inst_idx = #song.instruments + 1
    if not safeInsertInstrumentAt(song, source_inst_idx) then return end
    song.selected_instrument_index = source_inst_idx
    local source_inst = song.instruments[source_inst_idx]
    source_inst.name = stem_name .. " (Source - will be deleted)"
    source_inst:insert_sample_at(1)
    song.selected_sample_index = 1
    
    -- Load the audio file
    local load_success = pcall(function()
        source_inst.samples[1].sample_buffer:load_from(file_path)
    end)
    
    -- Yield after loading to prevent timeout on large files
    coroutine.yield()
    
    if not load_success or not source_inst.samples[1].sample_buffer.has_sample_data then
        print("DRUMKIT SLICING ERROR: Failed to load " .. file_path)
        song:delete_instrument_at(source_inst_idx)
        PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
        return false
    end
    
    local source_sample = source_inst.samples[1]
    local source_buffer = source_sample.sample_buffer
    local sample_rate = source_buffer.sample_rate
    local total_frames = source_buffer.number_of_frames
    local num_channels = source_buffer.number_of_channels
    local bit_depth = source_buffer.bit_depth
    
    source_sample.name = stem_name
    print(string.format("DRUMKIT SLICING: Loaded %s - %d frames at %d Hz, %d ch", stem_name, total_frames, sample_rate, num_channels))
    
    -- Calculate beat duration in frames
    local beat_duration_frames = (60 / bpm) * sample_rate
    
    -- 2. Process each beat length - create ONE drumkit instrument per beat length
    for _, beat_length in ipairs(beat_lengths_to_process) do
        print(string.format("DRUMKIT SLICING: Creating %d-beat drumkit for %s", beat_length, stem_name))
        
        -- Calculate slice frame size
        local slice_frames = math.floor(beat_duration_frames * beat_length)
        local num_slices = math.floor(total_frames / slice_frames)
        
        if num_slices < 1 then
            print(string.format("DRUMKIT SLICING: Skipping %d-beat - sample too short", beat_length))
        else
            -- Limit to 120 slices (Renoise max zones)
            num_slices = math.min(num_slices, 120)
            
            -- First pass: count non-silent slices
            local non_silent_slices = {}
            for slice_idx = 1, num_slices do
                local slice_start = math.floor((slice_idx - 1) * slice_frames) + 1
                local slice_end = math.min(math.floor(slice_idx * slice_frames), total_frames)
                
                if not isSliceRegionSilent(source_buffer, slice_start, slice_end) then
                    table.insert(non_silent_slices, {
                        start_frame = slice_start,
                        end_frame = slice_end,
                        original_idx = slice_idx
                    })
                end
            end
            
            local actual_sample_count = #non_silent_slices
            print(string.format("DRUMKIT SLICING: %d/%d slices are non-silent for %d-beat", 
                actual_sample_count, num_slices, beat_length))
            
            -- Skip creating instrument if ALL slices are silent
            if actual_sample_count == 0 then
                print(string.format("DRUMKIT SLICING: Skipping %d-beat drumkit - all slices are silent", beat_length))
            else
                -- Create new drumkit instrument at selected position + 1
                local drumkit_idx = song.selected_instrument_index + 1
                if not safeInsertInstrumentAt(song, drumkit_idx) then return end
                song.selected_instrument_index = drumkit_idx
                
                -- Load the drumkit template for proper key mappings
                pcall(function()
                    local defaultInstrument = preferences and preferences.pakettiDefaultDrumkitXRNI and preferences.pakettiDefaultDrumkitXRNI.value
                    if defaultInstrument and defaultInstrument ~= "" then
                        renoise.app():load_instrument(defaultInstrument)
                    else
                        renoise.app():load_instrument(renoise.tool().bundle_path .. "Presets/12st_Pitchbend_Drumkit_C0.xrni")
                    end
                end)
                
                local drumkit_inst = song.instruments[drumkit_idx]
                drumkit_inst.name = string.format("%s (%02d-beat) drumkit", stem_name, beat_length)
                
                -- Apply modulation settings
                PakettiApplyLoaderModulationSettings(drumkit_inst, "PakettiStemSlicer Direct Mode")
                
                -- Ensure at least one sample exists
                if #drumkit_inst.samples == 0 then drumkit_inst:insert_sample_at(1) end
                
                -- Create samples only for NON-SILENT slices
                for sample_idx, slice_info in ipairs(non_silent_slices) do
                    local slice_start = slice_info.start_frame
                    local slice_end = slice_info.end_frame
                    local slice_length = slice_end - slice_start + 1
                    
                    if slice_length > 0 then
                        -- Create sample slot if needed
                        if sample_idx == 1 then
                            -- Use existing first sample
                        else
                            drumkit_inst:insert_sample_at(sample_idx)
                        end
                        
                        local new_sample = drumkit_inst.samples[sample_idx]
                        new_sample.name = string.format("%s_%02dbeat_slice%02d", stem_name, beat_length, slice_info.original_idx)
                        
                        -- Create sample buffer and copy slice data
                        new_sample.sample_buffer:create_sample_data(sample_rate, bit_depth, num_channels, slice_length)
                        new_sample.sample_buffer:prepare_sample_data_changes()
                        
                        -- Copy audio data frame by frame
                        local frames_per_yield = 44100  -- Yield every second of audio
                        for frame = 1, slice_length do
                            local source_frame = slice_start + frame - 1
                            if source_frame <= total_frames then
                                for ch = 1, num_channels do
                                    local value = source_buffer:sample_data(ch, source_frame)
                                    new_sample.sample_buffer:set_sample_data(ch, frame, value)
                                end
                            end
                            -- Yield periodically for ProcessSlicer to prevent "terminate script?" dialogs
                            if frame % frames_per_yield == 0 then
                                coroutine.yield()
                            end
                        end
                        
                        new_sample.sample_buffer:finalize_sample_data_changes()
                        
                        -- Apply drumkit-specific settings
                        applyStemSlicerDrumkitSettings(new_sample)
                        
                        -- Set up drumkit mapping (each sample on a different key, all at C-4 pitch)
                        local key = sample_idx - 1  -- 0-based key (C-0, C#0, D-0, etc.)
                        new_sample.sample_mapping.base_note = 48  -- C-4: all samples play at same pitch
                        new_sample.sample_mapping.note_range = {key, key}  -- Each sample on unique key
                        new_sample.sample_mapping.map_key_to_pitch = false  -- Don't transpose based on key
                    end
                end
                
                -- Remove any leftover samples from the template
                while #drumkit_inst.samples > actual_sample_count do
                    drumkit_inst:delete_sample_at(#drumkit_inst.samples)
                end
                
                -- Finalize instrument
                finalizeInstrumentPaketti(drumkit_inst)
                
                -- Track the created instrument
                table.insert(direct_mode_instruments, drumkit_idx)
                
                print(string.format("DRUMKIT SLICING: Created drumkit '%s' with %d samples (skipped %d silent)", 
                    drumkit_inst.name, #drumkit_inst.samples, num_slices - actual_sample_count))
            end
        end
        
        -- Yield to keep UI responsive
        coroutine.yield()
    end
    
    -- 3. Cleanup - delete the source instrument
    -- Source instrument index may have shifted due to new instruments being added
    -- Find it by name
    local source_to_delete = nil
    for i = 1, #song.instruments do
        if song.instruments[i].name == stem_name .. " (Source - will be deleted)" then
            source_to_delete = i
            break
        end
    end
    
    if source_to_delete then
        -- Make sure we're not selecting it
        if song.selected_instrument_index == source_to_delete then
            song.selected_instrument_index = math.max(1, source_to_delete - 1)
        end
        
        -- Adjust tracked instrument indices (they shift down after deletion)
        local adjusted_instruments = {}
        for _, idx in ipairs(direct_mode_instruments) do
            if idx > source_to_delete then
                table.insert(adjusted_instruments, idx - 1)
            elseif idx < source_to_delete then
                table.insert(adjusted_instruments, idx)
            end
        end
        direct_mode_instruments = adjusted_instruments
        
        song:delete_instrument_at(source_to_delete)
        print(string.format("DRUMKIT SLICING: Deleted source instrument"))
    end
    
    -- Restore AutoSamplify monitoring
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    
    print(string.format("DRUMKIT SLICING: Completed %s, created %d drumkit instruments", stem_name, #direct_mode_instruments))
    
    return true
end

-- Process all files using native slicing (optimized direct mode)
local function processAllFilesNativeSlicing()
    if #audio_files == 0 then
        print("NATIVE SLICING: No audio files to process")
        return
    end
    
    -- Build list of beat lengths to process
    local beat_lengths_to_process = {master_beat_length}
    for _, bl in ipairs(extract_beat_lengths) do
        if bl < master_beat_length then
            table.insert(beat_lengths_to_process, bl)
        end
    end
    
    -- Sort from largest to smallest
    table.sort(beat_lengths_to_process, function(a, b) return a > b end)
    
    print(string.format("NATIVE SLICING: Processing %d files with beat lengths: %s", 
        #audio_files, table.concat(beat_lengths_to_process, ", ")))
    
    -- Reset tracking
    resetDirectModeTracking()
    direct_mode_used = true
    
    -- Process each file
    for file_idx, file_path in ipairs(audio_files) do
        current_progress = string.format("Native slicing file %d/%d", file_idx, #audio_files)
        renoise.app():show_status(current_progress)
        
        local success = processFileWithNativeSlicing(file_path, beat_lengths_to_process, target_bpm)
        
        if success then
            files_completed = files_completed + 1
        else
            files_skipped = files_skipped + 1
        end
        
        coroutine.yield()
    end
    
    -- Save session info for summary
    last_selected_folder = selected_folder
    last_bpm_used = target_bpm
    last_master_beat = master_beat_length
    last_subdivisions = {}
    for _, b in ipairs(extract_beat_lengths) do 
        table.insert(last_subdivisions, b) 
    end
    
    print(string.format("NATIVE SLICING COMPLETE: %d files processed, %d skipped, %d instruments created", 
        files_completed, files_skipped, #direct_mode_instruments))
end

-- Export slice directly to instrument (skip disk I/O) with grouping support
local function exportSliceDirectToInstrument(buffer, start_frame, end_frame, stem_name, beat_length, slice_index)
    local success, error_msg = pcall(function()
        -- CRITICAL OFF-BY-ONE PREVENTION: Clamp end_frame to buffer bounds
        end_frame = math.min(end_frame, buffer.number_of_frames)
        start_frame = math.max(start_frame, 1)
        
        local slice_length = end_frame - start_frame + 1
        
        -- CRITICAL SAFETY CHECK: Prevent massive buffer allocations
        if slice_length > 50000000 then
            error(string.format("Slice too large: %d frames (%.1f minutes) - possible calculation error", 
                slice_length, slice_length / 48000 / 60))
        end
        
        if slice_length <= 0 then
            error("Invalid slice length: " .. slice_length)
        end
        
        local song = renoise.song()
        local target_inst = nil
        local sample_idx = 1
        local slice_name = string.format("%s_%02dbeat_%03d", stem_name, beat_length, slice_index)
        
        -- Determine target instrument based on grouping mode
        if direct_grouping_mode == 1 then
            -- Per-sample: One instrument per slice
            local inst_idx = #song.instruments + 1
            if not safeInsertInstrumentAt(song, inst_idx) then return end
            song.selected_instrument_index = inst_idx
            target_inst = song.instruments[inst_idx]
            target_inst.name = slice_name
            target_inst:insert_sample_at(1)
            sample_idx = 1
            table.insert(direct_mode_instruments, inst_idx)
            print(string.format("DIRECT MODE (Per-sample): Created instrument %d: %s", inst_idx, slice_name))
            
        elseif direct_grouping_mode == 2 then
            -- Per-stem: One instrument per source stem file
            if direct_mode_stem_instruments[stem_name] then
                local inst_idx = direct_mode_stem_instruments[stem_name]
                target_inst = song.instruments[inst_idx]
                sample_idx = #target_inst.samples + 1
                target_inst:insert_sample_at(sample_idx)
                print(string.format("DIRECT MODE (Per-stem): Adding sample %d to %s", sample_idx, stem_name))
            else
                local inst_idx = #song.instruments + 1
                if not safeInsertInstrumentAt(song, inst_idx) then return end
                song.selected_instrument_index = inst_idx
                target_inst = song.instruments[inst_idx]
                target_inst.name = stem_name .. " (Slices)"
                target_inst:insert_sample_at(1)
                sample_idx = 1
                direct_mode_stem_instruments[stem_name] = inst_idx
                table.insert(direct_mode_instruments, inst_idx)
                print(string.format("DIRECT MODE (Per-stem): Created instrument %d for %s", inst_idx, stem_name))
            end
            
        elseif direct_grouping_mode == 3 then
            -- Per-beat: One instrument per beat length
            local beat_key = tostring(beat_length)
            if direct_mode_beat_instruments[beat_key] then
                local inst_idx = direct_mode_beat_instruments[beat_key]
                target_inst = song.instruments[inst_idx]
                sample_idx = #target_inst.samples + 1
                target_inst:insert_sample_at(sample_idx)
                print(string.format("DIRECT MODE (Per-beat): Adding sample %d to %d-beat instrument", sample_idx, beat_length))
            else
                local inst_idx = #song.instruments + 1
                if not safeInsertInstrumentAt(song, inst_idx) then return end
                song.selected_instrument_index = inst_idx
                target_inst = song.instruments[inst_idx]
                target_inst.name = string.format("StemSlicer %d-beat", beat_length)
                target_inst:insert_sample_at(1)
                sample_idx = 1
                direct_mode_beat_instruments[beat_key] = inst_idx
                table.insert(direct_mode_instruments, inst_idx)
                print(string.format("DIRECT MODE (Per-beat): Created instrument %d for %d-beat", inst_idx, beat_length))
            end
            
        elseif direct_grouping_mode == 4 then
            -- All combined: All slices into one mega-drumkit (max 120 samples)
            if direct_mode_combined_instrument and direct_mode_combined_sample_count < 120 then
                target_inst = song.instruments[direct_mode_combined_instrument]
                sample_idx = #target_inst.samples + 1
                target_inst:insert_sample_at(sample_idx)
                direct_mode_combined_sample_count = direct_mode_combined_sample_count + 1
                print(string.format("DIRECT MODE (Combined): Adding sample %d/%d", direct_mode_combined_sample_count, 120))
            elseif direct_mode_combined_sample_count >= 120 then
                -- Create new instrument when limit reached
                local inst_idx = #song.instruments + 1
                if not safeInsertInstrumentAt(song, inst_idx) then return end
                song.selected_instrument_index = inst_idx
                target_inst = song.instruments[inst_idx]
                target_inst.name = "StemSlicer Combined (overflow)"
                target_inst:insert_sample_at(1)
                sample_idx = 1
                direct_mode_combined_instrument = inst_idx
                direct_mode_combined_sample_count = 1
                table.insert(direct_mode_instruments, inst_idx)
                print(string.format("DIRECT MODE (Combined): Created overflow instrument %d", inst_idx))
            else
                local inst_idx = #song.instruments + 1
                if not safeInsertInstrumentAt(song, inst_idx) then return end
                song.selected_instrument_index = inst_idx
                target_inst = song.instruments[inst_idx]
                target_inst.name = "StemSlicer Combined"
                target_inst:insert_sample_at(1)
                sample_idx = 1
                direct_mode_combined_instrument = inst_idx
                direct_mode_combined_sample_count = 1
                table.insert(direct_mode_instruments, inst_idx)
                print(string.format("DIRECT MODE (Combined): Created combined instrument %d", inst_idx))
            end
        end
        
        -- Get target sample
        local target_sample = target_inst.samples[sample_idx]
        target_sample.name = slice_name
        
        -- Create buffer for the slice
        target_sample.sample_buffer:create_sample_data(
            buffer.sample_rate, 
            buffer.bit_depth, 
            buffer.number_of_channels, 
            slice_length
        )
        
        target_sample.sample_buffer:prepare_sample_data_changes()
        
        -- Copy the region data with SAFE bounds checking
        local frames_per_yield = 44100  -- Yield every second of audio
        local max_frame = math.min(slice_length, 10000000)  -- SAFETY: Never more than 10M frames
        
        for ch = 1, math.min(buffer.number_of_channels, 8) do  -- SAFETY: Max 8 channels
            for frame = 1, max_frame do
                local source_frame = start_frame + frame - 1
                
                -- CRITICAL OFF-BY-ONE FIX: Ensure we never exceed buffer bounds
                if source_frame >= 1 and source_frame <= math.min(buffer.number_of_frames, end_frame) then
                    target_sample.sample_buffer:set_sample_data(ch, frame, buffer:sample_data(ch, source_frame))
                else
                    -- Fill with silence if out of bounds
                    target_sample.sample_buffer:set_sample_data(ch, frame, 0.0)
                end
                
                -- Yield periodically to keep UI responsive
                if frame % frames_per_yield == 0 then
                    coroutine.yield()
                end
                
                -- SAFETY BREAK
                if frame > slice_length then
                    print("WARNING: Frame loop safety break triggered")
                    break
                end
            end
        end
        
        target_sample.sample_buffer:finalize_sample_data_changes()
        
        -- Apply Paketti loader settings to the sample
        if PakettiInjectApplyLoaderSettings then
            PakettiInjectApplyLoaderSettings(target_sample)
        end
        
        -- Reset consecutive error counter on successful export
        resetConsecutiveErrors()
        
        -- Memory leak prevention
        if not checkMemoryUsage() then
            error("Processing timeout detected - stopping to prevent system freeze")
        end
        
        print(string.format("DIRECT MODE: Created slice %s in instrument", slice_name))
    end)
    
    return success, error_msg or ""
end

-- Process a single audio file using direct visual approach (SEQUENTIAL PROCESSING)
local function processSingleFile(file_path, output_folder)
    local file_name = file_path:match("[^/\\]+$") or file_path
    print("=== STARTING SEQUENTIAL PROCESSING ===")
    print(string.format("Processing file [%s]: %s", os.date("%H:%M:%S"), file_path))
    
    -- CRITICAL FIX: Clear any stale state before processing this file
    clearSilenceMap()
    collectgarbage("collect") -- Force garbage collection before each file
    
    -- DEBUGGING: Log initial state
    local song = renoise.song()
    print(string.format("FILE DEBUG [%s]: Initial instruments=%d, selected=%d", 
        file_name, #song.instruments, song.selected_instrument_index))
    
    -- Ensure we're not doing anything else while processing this file
    coroutine.yield() -- Give UI a chance to update before starting
    
    local song = renoise.song()
    local clean_name = getCleanFilename(file_path)
    local file_ext = getFileExtension(file_path)
    
    current_progress = string.format("Loading %s into Renoise...", clean_name)
    coroutine.yield()
    
    -- Step 1: Use provided instrument or create new one (OPTIMIZATION)
    local new_inst_idx
    local new_inst
    local sample
    
    -- CRASH FIX: Always create fresh instrument for each file (no reuse to avoid UI conflicts)
    local original_inst_count = #song.instruments
    new_inst_idx = original_inst_count + 1
    if not safeInsertInstrumentAt(song, new_inst_idx) then return end
    song.selected_instrument_index = new_inst_idx
    new_inst = song.instruments[new_inst_idx]
    new_inst.name = clean_name
    
    new_inst:insert_sample_at(1)
    song.selected_sample_index = 1
    sample = new_inst.samples[1]
    sample.name = clean_name
    
    -- Load the file
    local load_success = false
    pcall(function()
        sample.sample_buffer:load_from(file_path)
        load_success = true
    end)
    
    if not load_success then
        local error_msg = "Failed to load: " .. file_path
        print(error_msg)
        renoise.app():show_status(error_msg)
        -- Clean up failed instrument immediately
        song:delete_instrument_at(new_inst_idx)
        return false
    end
    
    local buffer = sample.sample_buffer
    local sample_rate = buffer.sample_rate
    local total_frames = buffer.number_of_frames
    
    print(string.format("  Loaded into instrument %d: %d Hz, %d frames", new_inst_idx, sample_rate, total_frames))
    
    -- Switch to sample editor view so user can see progress
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
    
    -- Create silence map for entire file (HIERARCHICAL OPTIMIZATION)
    current_progress = string.format("Analyzing audio patterns for %s...", clean_name)
    coroutine.yield()
    
    local silence_map = createSilenceMapForFile(buffer, file_path)
    
    -- Pre-generate silence files for all beat lengths we'll need (OPTIMIZATION)
    -- Skip this entirely in direct mode - no files are written to disk
    if not direct_to_instruments then
        current_sample_name = string.format("%s - Preparing silence files", clean_name)
        current_progress = string.format("Pre-generating silence files for %s...", clean_name)
        coroutine.yield()
        
        local needed_beat_lengths = {master_beat_length}
        for _, beat_length in ipairs(extract_beat_lengths) do
            table.insert(needed_beat_lengths, beat_length)
        end
        
        for _, beat_length in ipairs(needed_beat_lengths) do
            generateSilenceFile(beat_length, sample_rate, output_folder)
        end
    else
        print("DIRECT MODE: Skipping silence file pre-generation (no disk I/O)")
    end
    
    -- Step 2: Add slice markers for master beat length
    current_sample_name = string.format("%s - Adding %d-beat markers", clean_name, master_beat_length)
    current_progress = string.format("Adding %d-beat slice markers...", master_beat_length)
    coroutine.yield()
    
    local beat_duration_frames = calculateBeatDurationFrames(target_bpm, sample_rate)
    local master_slice_frames = beat_duration_frames * master_beat_length
    local num_master_slices = math.floor(total_frames / master_slice_frames)
    
    -- Check if there's a remainder that needs a final slice
    local remainder_frames = total_frames - (num_master_slices * master_slice_frames)
    local has_final_slice = remainder_frames > (master_slice_frames * 0.1) -- At least 10% of slice length
    
    print(string.format("  Adding %d slice markers every %d frames (%d beats)", num_master_slices, master_slice_frames, master_beat_length))
    if has_final_slice then
        print(string.format("  Final slice: %d frames remainder (%.1f%% of full slice)", remainder_frames, (remainder_frames/master_slice_frames)*100))
    end
    
    -- Clear existing markers and add new ones
    while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
    end
    
    -- CRITICAL FIX: Don't insert marker at frame 1 (beginning), only at cut points
    for slice_idx = 1, num_master_slices - 1 do -- Note: -1 to avoid marker at beginning
        local slice_start = slice_idx * master_slice_frames + 1
        if slice_start <= total_frames then
            sample:insert_slice_marker(slice_start)
            print(string.format("  Added slice marker at frame %d (slice %d boundary)", slice_start, slice_idx + 1))
        end
    end
    
    -- Add marker for final slice if there's a significant remainder
    if has_final_slice then
        local final_slice_start = num_master_slices * master_slice_frames + 1
        if final_slice_start < total_frames then
            sample:insert_slice_marker(final_slice_start)
        end
    end
    
    -- Step 3: Save master beat slices directly from sample editor with visual selection
    current_sample_name = string.format("%s - Exporting %d-beat slices", clean_name, master_beat_length)
    current_progress = string.format("Exporting %d-beat slices...", master_beat_length)
    coroutine.yield()
    
    local slice_positions = {1} -- Start with beginning
    for i = 1, #sample.slice_markers do
        table.insert(slice_positions, sample.slice_markers[i])
    end
    table.insert(slice_positions, total_frames + 1) -- End marker
    
    -- Export master beat slices
    print(string.format("SLICE EXPORT DEBUG [%s]: Starting master beat export, %d slice positions", 
        file_name, #slice_positions))
    
    for slice_idx = 1, #slice_positions - 1 do
        -- CRITICAL: Check for cancellation during slice processing
        if isProcessingCancelled() then
            print(string.format("CANCELLATION: Export cancelled during slice %d of file %s", slice_idx, file_name))
            return false
        end
        local slice_start = slice_positions[slice_idx]
        local slice_end = slice_positions[slice_idx + 1] - 1
        local slice_length = slice_end - slice_start + 1
        
        print(string.format("SLICE DEBUG [%s]: Processing slice %d/%d (start=%d, end=%d, length=%d)", 
            file_name, slice_idx, #slice_positions - 1, slice_start, slice_end, slice_length))
        
        if slice_length > 0 then
            -- CRITICAL FIX: Avoid visual selection during batch processing to prevent BPM observer interference
            -- Only set selection if we're not in background processing mode
            if dialog and dialog.visible then
                buffer.selection_start = slice_start
                buffer.selection_end = slice_end
                print(string.format("SLICE DEBUG [%s]: Set visual selection for UI", file_name))
            else
                print(string.format("SLICE DEBUG [%s]: Skipped visual selection (background processing)", file_name))
            end
            
            current_progress = string.format("Exporting %s: %d-beat slice %d/%d", 
                clean_name, master_beat_length, slice_idx, #slice_positions - 1)
            renoise.app():show_status(current_progress)
            
            -- Check for silence using pre-computed map (HIERARCHICAL OPTIMIZATION)
            local is_silent = checkSilenceUsingMap(slice_start, slice_end, silence_map)
            local silence_suffix = is_silent and "_silence" or ""
            
            local output_filename = string.format("%s_%02dbeats_slice%03d%s.wav", 
                clean_name, master_beat_length, slice_idx, silence_suffix)
            local output_path = output_folder .. "/" .. output_filename
            
            local export_success = false
            local export_error_msg = ""
            
            print(string.format("EXPORT DEBUG [%s]: About to export slice %d, silent=%s, filename=%s", 
                file_name, slice_idx, tostring(is_silent), output_filename))
            
            if is_silent then
                if skip_writing_silence or direct_to_instruments then
                    -- Skip writing silence files entirely (always skip in direct mode - no disk I/O)
                    if direct_to_instruments then
                        print(string.format("DIRECT MODE SKIPPED SILENCE [%s]: %s", file_name, output_filename))
                    else
                        print(string.format("SKIPPED SILENCE [%s]: %s", file_name, output_filename))
                    end
                    export_success = true  -- Mark as success since we intentionally skipped it
                else
                    -- OPTIMIZATION: Copy pre-generated silence file instead of exporting
                    local silence_source = generateSilenceFile(master_beat_length, sample_rate, output_folder)
                    export_success = copySilenceFile(silence_source, output_path)
                    if export_success then
                        print(string.format("EXPORT SUCCESS [%s]: Copied silence: %s", file_name, output_filename))
                        resetConsecutiveErrors() -- Reset circuit breaker on successful silence copy
                    else
                        export_error_msg = string.format("Failed to copy silence: %s", output_filename)
                        print(string.format("EXPORT FAILED [%s]: %s", file_name, export_error_msg))
                    end
                end
            else
                -- Export actual audio slice
                if direct_to_instruments then
                    -- Direct mode: Create instrument directly (skip disk I/O)
                    export_success, export_error_msg = exportSliceDirectToInstrument(buffer, slice_start, slice_end, clean_name, master_beat_length, slice_idx)
                    if export_success then
                        print(string.format("DIRECT EXPORT SUCCESS [%s]: Created instrument: %s", file_name, output_filename))
                    else
                        local full_error = string.format("Failed to create direct instrument for slice %d: %s", slice_idx, export_error_msg)
                        print(string.format("DIRECT EXPORT FAILED [%s]: %s", file_name, full_error))
                        renoise.app():show_status(full_error)
                        logProcessingError("DIRECT_EXPORT_FAILED", file_path, full_error)
                    end
                else
                    -- Normal mode: Export to WAV file
                    export_success, export_error_msg = exportSliceRegion(buffer, slice_start, slice_end, output_path)
                    if export_success then
                        print(string.format("EXPORT SUCCESS [%s]: Exported audio: %s", file_name, output_filename))
                    else
                        local full_error = string.format("Failed to export audio slice %d: %s", slice_idx, export_error_msg)
                        print(string.format("EXPORT FAILED [%s]: %s", file_name, full_error))
                        renoise.app():show_status(full_error)
                        
                        -- CRITICAL: If export fails, log it but don't stop processing other slices
                        logProcessingError("EXPORT_FAILED", file_path, full_error)
                    end
                end
            end
            
            if not export_success then
                print(string.format("EXPORT ERROR [%s]: Slice %d failed, continuing with next slice...", file_name, slice_idx))
            end
            
            -- Yield after each master slice export to prevent script timeout
            coroutine.yield()
        end
    end
    
    -- Step 4: Now create subdivisions from the master slices
    for _, beat_length in ipairs(extract_beat_lengths) do
        -- CRITICAL: Check for cancellation during subdivision processing
        if isProcessingCancelled() then
            print(string.format("CANCELLATION: Subdivision export cancelled during %d-beat processing of %s", beat_length, file_name))
            return false
        end
        
        if beat_length < master_beat_length then
            local subdivisions_per_master = master_beat_length / beat_length
            
            current_sample_name = string.format("%s - Creating %d-beat subdivisions", clean_name, beat_length)
            current_progress = string.format("Creating %d-beat subdivisions...", beat_length)
            coroutine.yield()
            
            for slice_idx = 1, #slice_positions - 1 do
                local slice_start = slice_positions[slice_idx]
                local slice_end = slice_positions[slice_idx + 1] - 1
                local slice_length = slice_end - slice_start + 1
                local subdivision_frames = math.floor(slice_length / subdivisions_per_master)
                
                -- Create subdivisions of this master slice
                for sub_idx = 1, subdivisions_per_master do
                    local sub_start = slice_start + (sub_idx - 1) * subdivision_frames
                    local sub_end = math.min(sub_start + subdivision_frames - 1, slice_end)
                    local sub_length = sub_end - sub_start + 1
                    
                    if sub_length > 0 then
                        -- Visual selection
                        buffer.selection_start = sub_start
                        buffer.selection_end = sub_end
                        
                        local overall_slice_num = (slice_idx - 1) * subdivisions_per_master + sub_idx
                        current_progress = string.format("Exporting %s: %d-beat slice %d (from %d-beat slice %d)", 
                            clean_name, beat_length, overall_slice_num, master_beat_length, slice_idx)
                        renoise.app():show_status(current_progress)
                        
                        -- Check for silence using pre-computed map (HIERARCHICAL OPTIMIZATION)
                        local is_silent = checkSilenceUsingMap(sub_start, sub_end, silence_map)
                        local silence_suffix = is_silent and "_silence" or ""
                        
                        local output_filename = string.format("%s_%02dbeats_slice%03d%s.wav", 
                            clean_name, beat_length, overall_slice_num, silence_suffix)
                        local output_path = output_folder .. "/" .. output_filename
                        
                        local export_success = false
                        if is_silent then
                            if skip_writing_silence or direct_to_instruments then
                                -- Skip writing silence files entirely (always skip in direct mode - no disk I/O)
                                if direct_to_instruments then
                                    print(string.format("    DIRECT MODE SKIPPED SILENCE: %s", output_filename))
                                else
                                    print(string.format("    SKIPPED SILENCE: %s", output_filename))
                                end
                                export_success = true  -- Mark as success since we intentionally skipped it
                            else
                                -- OPTIMIZATION: Copy pre-generated silence file instead of exporting
                                local silence_source = generateSilenceFile(beat_length, sample_rate, output_folder)
                                export_success = copySilenceFile(silence_source, output_path)
                                if export_success then
                                    print(string.format("    Copied silence: %s", output_filename))
                                    resetConsecutiveErrors() -- Reset circuit breaker on successful silence copy
                                else
                                    print(string.format("    Failed to copy silence: %s", output_filename))
                                end
                            end
                        else
                            -- Export actual audio subdivision
                            if direct_to_instruments then
                                -- Direct mode: Create instrument directly (skip disk I/O)
                                export_success = exportSliceDirectToInstrument(buffer, sub_start, sub_end, clean_name, beat_length, overall_slice_num)
                                if export_success then
                                    print(string.format("    Direct created: %s", output_filename))
                                else
                                    local export_error = string.format("    Failed to create direct: %s", output_filename)
                                    print(export_error)
                                    renoise.app():show_status(export_error)
                                end
                            else
                                -- Normal mode: Export to WAV file
                                export_success = exportSliceRegion(buffer, sub_start, sub_end, output_path)
                                if export_success then
                                    print(string.format("    Exported: %s", output_filename))
                                else
                                    local export_error = string.format("    Failed to export: %s", output_filename)
                                    print(export_error)
                                    renoise.app():show_status(export_error)
                                end
                            end
                        end
                        
                        -- Yield after each subdivision export to prevent script timeout
                        coroutine.yield()
                    end
                end
            end
        end
    end
    
    print(string.format("FILE COMPLETION [%s]: All slice exports complete", file_name))
    
    -- DEBUGGING: Count actual exported files to verify everything worked
    local exported_files = 0
    local success_files = 0
    local silence_files = 0
    
    -- Count files that should have been created
    local expected_master_slices = #slice_positions - 1
    local expected_subdivisions = 0
    for _, beat_length in ipairs(extract_beat_lengths) do
        if beat_length < master_beat_length then
            local subdivisions_per_master = master_beat_length / beat_length
            expected_subdivisions = expected_subdivisions + (expected_master_slices * subdivisions_per_master)
        end
    end
    local expected_total = expected_master_slices + expected_subdivisions
    
    print(string.format("FILE SUMMARY [%s]: Expected %d total slices (%d master + %d subdivisions)", 
        file_name, expected_total, expected_master_slices, expected_subdivisions))
    
    -- CRASH FIX: Clean up this file's instrument immediately after ALL exports are done
    print(string.format("FILE CLEANUP [%s]: Ensuring all exports complete, cleaning up instrument %d", file_name, new_inst_idx))
    coroutine.yield() -- Let any pending operations complete
    coroutine.yield() -- Extra safety yield
    coroutine.yield() -- Even more safety
    
    -- Verify instrument still exists before deletion
    if new_inst_idx <= #song.instruments then
        song:delete_instrument_at(new_inst_idx)
        print(string.format("FILE CLEANUP [%s]: Successfully cleaned up instrument", file_name))
    else
        print(string.format("FILE CLEANUP [%s]: Instrument already removed or out of range", file_name))
    end
    
    print(string.format("FILE COMPLETE [%s]: Processing finished successfully", file_name))
    return true
end

-- Main processing function for ProcessSlicer
local function processAllFiles()
    if #audio_files == 0 then
        local error_msg = "No audio files found in selected folder"
        print(error_msg)
        renoise.app():show_status(error_msg)
        return
    end
    
    -- Clear silence cache and map for fresh processing session (OPTIMIZATION)
    clearSilenceCache()
    clearSilenceMap()
    
    -- Clear export instrument for fresh session (CRASH PREVENTION)
    if export_instrument_idx then
        cleanupExportInstrument()
    end
    
    -- Reset and track direct mode state for this session
    resetDirectModeTracking()
    direct_mode_used = direct_to_instruments  -- Track if direct mode was used
    if direct_to_instruments then
        print("DIRECT MODE: Enabled - slices will be created directly as instruments")
    end
    
    -- Initialize progress and error tracking (OPTIMIZATION)
    files_completed = 0
    total_files_to_process = #audio_files
    current_sample_name = "Starting..."
    clearErrorTracking()
    resetDialogFloodPrevention() -- Reset dialog flood prevention for new session
    
    -- Initialize memory leak prevention (CRITICAL)
    resetMemoryTracking()
    print("MEMORY: Started with garbage collection and memory tracking")
    
    -- Create output folder (skip in direct mode - no disk I/O)
    local output_folder = selected_folder .. "/PakettiStemSlicer_Output"
    
    if not direct_to_instruments then
        -- Create output directory using OS-specific command
        local mkdir_cmd
        if package.config:sub(1,1) == "\\" then  -- Windows
            mkdir_cmd = string.format('mkdir "%s" 2>nul', output_folder:gsub("/", "\\"))
        else  -- macOS and Linux
            mkdir_cmd = string.format("mkdir -p '%s'", output_folder:gsub("'", "'\\''"))
        end
        os.execute(mkdir_cmd)
    else
        print("DIRECT MODE: Skipping output folder creation (no disk I/O)")
    end
    
    print(string.format("=== PakettiStemSlicer Processing ==="))
    print(string.format("Input folder: %s", selected_folder))
    if direct_to_instruments then
        print("Output: DIRECT TO INSTRUMENTS (no disk I/O)")
    else
        print(string.format("Output folder: %s", output_folder))
    end
    print(string.format("Target BPM: %.1f", target_bpm))
    print(string.format("Files to process: %d", #audio_files))
    print(string.format("Beat lengths: %s", table.concat(ALL_BEAT_LENGTHS, ", ")))
    
    -- Process each file sequentially with complete cleanup (CRASH FIX)
    for file_idx, file_path in ipairs(audio_files) do
        -- CRITICAL FIX: Check for cancellation more frequently and break immediately
        if isProcessingCancelled() then
            print("CANCELLATION: Processing cancelled by user at file", file_idx)
            
            -- CRITICAL: Clean up temp export instrument when cancelled
            if export_instrument_idx then
                print("CANCELLATION CLEANUP: Removing temp export instrument")
                cleanupExportInstrument()
            end
            
            return -- Exit the function immediately
        end
        
        -- Check for critical error threshold
        if critical_errors >= 5 then
            -- NOTE: Don't call logProcessingError here to avoid triggering circuit breaker
            -- when we're already stopping due to too many critical errors
            print("CRITICAL ERROR THRESHOLD: Too many critical errors (" .. critical_errors .. "), stopping processing")
            
            -- CRITICAL: Clean up temp export instrument on error exit
            if export_instrument_idx then
                print("CLEANUP: Removing temp export instrument after critical errors")
                cleanupExportInstrument()
            end
            
            break
        end
        
        -- Update current sample name for progress display
        current_sample_name = getCleanFilename(file_path)
        current_progress = string.format("Processing file %d/%d: %s", file_idx, #audio_files, current_sample_name)
        
        -- Clear silence map for each new file (HIERARCHICAL OPTIMIZATION)
        clearSilenceMap()
        
        -- Process file completely before moving to next (SEQUENTIAL PROCESSING)
        local status, result1 = pcall(function()
            return processSingleFile(file_path, output_folder)
        end)
        
        if status then
            local success = result1
            if success then
                files_completed = files_completed + 1  -- Update progress tracking
                print(string.format("Successfully completed file %d/%d", file_idx, #audio_files))
                
                -- Reset consecutive error counter on successful file completion
                resetConsecutiveErrors()
            else
                logProcessingError("LOAD_FAILED", file_path, "Failed to load file")
            end
        else
            local error_msg = tostring(result1)
            if error_msg:find("memory") or error_msg:find("out of") then
                logProcessingError("CRITICAL", file_path, "Memory error: " .. error_msg)
            else
                logProcessingError("PROCESSING_ERROR", file_path, error_msg)
            end
        end
        
        -- Extra safety yield between files to prevent overlapping operations
        print(string.format("=== File %d/%d COMPLETE - Preparing for next file ===", file_idx, #audio_files))
        coroutine.yield()
        coroutine.yield()
        coroutine.yield()
        if file_idx < #audio_files then
            print(string.format("=== Starting file %d/%d ===", file_idx + 1, #audio_files))
        end
    end
    
    current_progress = "Processing complete!"
    current_sample_name = "All files completed"
    print("=== Processing Complete ===")
    print(generateErrorSummary())
    local status_msg = string.format("PakettiStemSlicer: Processed %d files", files_completed)
    if files_skipped > 0 then
        status_msg = status_msg .. string.format(" (%d skipped due to errors)", files_skipped)
    end
    renoise.app():show_status(status_msg)
    -- Save session context for summary dialog
    last_output_folder = output_folder
    last_selected_folder = selected_folder
    last_bpm_used = target_bpm
    last_master_beat = master_beat_length
    last_subdivisions = {}
    for _, b in ipairs(extract_beat_lengths) do table.insert(last_subdivisions, b) end
end

-- Helper function to extract BPM from folder name
-- Looks for patterns like: 146BPM, _146bpm, BPM146, 146-bpm, 146_BPM, etc.
local function extractBpmFromFolderName(folder_path)
    if not folder_path or folder_path == "" then
        return nil
    end
    
    -- Extract just the folder name from the full path
    -- Remove trailing slash if present
    local clean_path = folder_path:gsub("[/\\]+$", "")
    -- Get the last component of the path
    local folder_name = clean_path:match("([^/\\]+)$")
    
    if not folder_name then
        print("BPM EXTRACT: Could not extract folder name from path: " .. folder_path)
        return nil
    end
    
    print("BPM EXTRACT: Checking folder name: " .. folder_name)
    
    -- Convert to lowercase for case-insensitive matching
    local lower_name = folder_name:lower()
    
    local detected_bpm = nil
    
    -- Pattern 1: Number followed by "bpm" (e.g., "146BPM", "146bpm", "146_bpm", "146-bpm", "146 bpm")
    -- This handles: 146BPM, 146bpm, 146_BPM, 146-bpm, 146 bpm
    local bpm_after = lower_name:match("(%d+)[%s_%-]*bpm")
    if bpm_after then
        detected_bpm = tonumber(bpm_after)
        print("BPM EXTRACT: Found pattern 'NUMbpm': " .. tostring(detected_bpm))
    end
    
    -- Pattern 2: "bpm" followed by number (e.g., "BPM146", "bpm_146", "bpm-146", "bpm 146")
    if not detected_bpm then
        local bpm_before = lower_name:match("bpm[%s_%-]*(%d+)")
        if bpm_before then
            detected_bpm = tonumber(bpm_before)
            print("BPM EXTRACT: Found pattern 'bpmNUM': " .. tostring(detected_bpm))
        end
    end
    
    -- Validate BPM is in reasonable range (1-999)
    if detected_bpm then
        if detected_bpm >= 1 and detected_bpm <= 999 then
            print("BPM EXTRACT: Valid BPM detected: " .. tostring(detected_bpm))
            return detected_bpm
        else
            print("BPM EXTRACT: BPM out of range (1-999): " .. tostring(detected_bpm))
            return nil
        end
    end
    
    print("BPM EXTRACT: No BPM pattern found in folder name")
    return nil
end

-- Browse for folder containing audio files
local function browseForFolder()
    local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
    if folder_path and folder_path ~= "" then
        selected_folder = folder_path
        audio_files = getSupportedAudioFiles(folder_path)
        
        -- Try to extract BPM from folder name to help the user
        local detected_bpm = extractBpmFromFolderName(folder_path)
        local bpm_status_suffix = ""
        
        if detected_bpm then
            target_bpm = detected_bpm
            if dialog and dialog.visible and vb.views.bpm_input then
                vb.views.bpm_input.value = detected_bpm
            end
            bpm_status_suffix = string.format(", BPM auto-detected: %d", detected_bpm)
            print("BPM AUTO-SET: Set target BPM to " .. tostring(detected_bpm) .. " from folder name")
        end
        
        if dialog and dialog.visible then
            vb.views.folder_display.text = string.format("%s (%d files)", folder_path, #audio_files)
            vb.views.process_button.active = #audio_files > 0
        end
        
        renoise.app():show_status(string.format("Selected folder with %d audio files%s", #audio_files, bpm_status_suffix))
    else
        renoise.app():show_status("No folder selected")
    end
end

-- Start processing with ProcessSlicer
local function startProcessing()
    if #audio_files == 0 then
        renoise.app():show_warning("No audio files found. Please select a folder containing audio files.")
        return
    end
    
    if target_bpm <= 0 or target_bpm > 999 then
        renoise.app():show_warning("Please enter a valid BPM between 1 and 999.")
        return
    end
    
    -- Create and start ProcessSlicer with cleanup wrapper
    process_slicer = ProcessSlicer(function()
        if direct_to_instruments then
            -- OPTIMIZED: Use native slicing + PakettiIsolateSlicesToInstrument
            -- This is MUCH faster than frame-by-frame copying
            print("STARTING: Optimized native slicing mode")
            processAllFilesNativeSlicing()
        else
            -- Normal mode: Export to WAV files
            print("STARTING: Normal WAV export mode")
            processAllFiles()
            
            -- Ensure cleanup happens after processing completes normally
            if export_instrument_idx then
                print("NORMAL COMPLETION: Final cleanup of temp export instrument")
                cleanupExportInstrument()
            end
        end
    end)
    
    local progress_dialog, progress_vb = process_slicer:create_dialog("Paketti Stem Slicer Processing...")
    
    -- Update progress text periodically and handle completion
    local progress_timer = nil
    local cancellation_timer_created = false -- CRITICAL: Prevent multiple cancellation timers
    
    progress_timer = renoise.tool():add_timer(function()
        -- CRITICAL: Stop timer immediately if processing was cancelled globally
        if processing_cancelled then
            if progress_timer then
                renoise.tool():remove_timer(progress_timer)
                progress_timer = nil
                print("TIMER STOPPED: Processing cancelled globally")
            end
            return
        end
        
        if progress_dialog and progress_dialog.visible and progress_vb then
            progress_vb.views.progress_text.text = calculateProgress()
        end
        
        -- Check if ProcessSlicer was cancelled and handle cleanup
        if not process_slicer:running() and process_slicer:was_cancelled() and not completion_handled and not cancellation_timer_created then
            completion_handled = true -- Prevent multiple handlers
            cancellation_timer_created = true -- Prevent multiple cancellation timers
            markProcessingCancelled() -- Use the global cancellation flag
            print("PROCESS CANCELLED: Cleaning up temp export instrument")
            
            -- CRITICAL: Remove timer FIRST to prevent further executions
            if progress_timer then
                renoise.tool():remove_timer(progress_timer)
                progress_timer = nil
                print("CANCEL: Timer removed successfully")
            end
            
            -- Clean up temp export instrument when cancelled via progress dialog
            if export_instrument_idx then
                print("CANCEL CLEANUP: Removing temp export instrument")
                cleanupExportInstrument()
            end
            
            -- Close progress dialog and return to original
            if progress_dialog and progress_dialog.visible then 
                progress_dialog:close() 
                print("CANCEL: Progress dialog closed")
            end
            
            -- SINGLE delayed call - won't repeat because cancellation_timer_created is now true
            renoise.tool():add_timer(function()
                print("CANCEL: One-time delayed return to original dialog")
                returnToOriginalDialogWithCompletion()
            end, 200) -- Wait 200ms to ensure timer cleanup is complete
            
            
        elseif not process_slicer:running() and not completion_handled then
            completion_handled = true -- EMERGENCY: Prevent multiple completion handlers
            markProcessingComplete() -- Mark processing as complete to prevent dialog flooding
            
            -- CRITICAL: Remove timer FIRST to prevent further executions
            if progress_timer then
                renoise.tool():remove_timer(progress_timer)
                progress_timer = nil
                print("COMPLETION: Timer removed successfully")
            end
            
            print("PROCESSING COMPLETE: Starting completion sequence (once only)")
            
            -- CRITICAL: Clean up temp export instrument OUTSIDE ProcessSlicer context
            if export_instrument_idx then
                print("CLEANUP: Removing temp export instrument")
                cleanupExportInstrument()
            end
            
            -- FIXED: Update progress dialog to show completion properly
            if progress_dialog and progress_dialog.visible and progress_vb then
                -- Note: Can't change dialog title in Renoise, so skip that
                
                -- Update progress text to show clean completion message
                if progress_vb.views.progress_text then
                    local completion_message = string.format("Processing complete! %d files processed", files_completed)
                    if files_skipped > 0 then
                        completion_message = completion_message .. string.format(" (%d skipped)", files_skipped)
                    end
                    progress_vb.views.progress_text.text = completion_message
                    print("UPDATED: Progress text to show clean completion message")
                end
                
                -- Change button to "Close"
                if progress_vb.views.cancel_button then
                    progress_vb.views.cancel_button.text = "Close"
                    print("UPDATED: Button text to 'Close'")
                end
                
                -- Wait a moment before auto-closing to let user see completion
                renoise.tool():add_timer(function()
                    if progress_dialog and progress_dialog.visible then 
                        progress_dialog:close() 
                    end
                    -- FIXED: Return to original dialog instead of showing new completion dialog
                    print("TIMER: Returning to original dialog after 1.5 second delay")
                    returnToOriginalDialogWithCompletion()
                end, 1500) -- Wait 1.5 seconds
            else
                if progress_dialog and progress_dialog.visible then progress_dialog:close() end
                -- FIXED: Return to original dialog instead of showing new completion dialog
                print("DIRECT: Returning to original dialog immediately")
                returnToOriginalDialogWithCompletion()
            end
        end
    end, 100) -- Update every 100ms
    
    process_slicer:start()
end

-- Main dialog function with error handling
function pakettiStemSlicerDialog()
    local success, error_msg = pcall(function()
        pakettiStemSlicerDialogInternal()
    end)
    
    if not success then
        local full_error = "ERROR in pakettiStemSlicerDialog: " .. tostring(error_msg)
        print(full_error)
        renoise.app():show_status(full_error)
    end
end

-- Internal dialog function
function pakettiStemSlicerDialogInternal()
    if dialog and dialog.visible then
        cleanupStemSlicerBpmObservable()
        dialog:close()
        dialog = nil
        return
    end
    
    -- Create fresh ViewBuilder instance to avoid ID collisions
    vb = renoise.ViewBuilder()
    current_progress = "Ready to process..."
    
    local content = vb:column{
        vb:text{
            text = "Slice audio stems into BPM-synchronized beat chunks",
            style = "normal"
        },
        vb:text{
          text = "Naming format: originalname_XXbeats_sliceYY.wav, silent slices marked with _silence suffix",
          style = "normal"
      },    

        
        
        -- Folder selection
        vb:button{text="Browse Folder",width=120,notifier = browseForFolder},
        
        vb:text{id="folder_display",text="No folder selected",width=400,style="strong",font="bold"},
        -- BPM input
        vb:row{
            vb:text{
                text = "Target BPM",
                width = 100,
                style = "strong", font="bold"
            },
            vb:valuebox{
                id = "bpm_input",
                value = target_bpm,
                width=100,
                min = 1,
                max = 999,
                notifier = function(value)
                    target_bpm = value
                end
            }
        },
        -- Master beat length selection
        vb:row{vb:text{
            text = "Master Slice Size",
            style = "strong", font="bold",width=100
        },
            vb:popup{
                id = "master_beat_popup",
                items = {"1 beats", "2 beats", "4 beats", "8 beats", "16 beats", "32 beats", "64 beats"},
                value = 7, -- Default to 64 beats
                width = 100,
                notifier = function(index)
                    master_beat_length = ALL_BEAT_LENGTHS[index]
                    -- Update subdivision checkboxes availability
                    vb.views.extract_1.active = (master_beat_length > 1)
                    vb.views.extract_2.active = (master_beat_length > 2)
                    vb.views.extract_4.active = (master_beat_length > 4)
                    vb.views.extract_8.active = (master_beat_length > 8)
                    vb.views.extract_16.active = (master_beat_length > 16)
                    vb.views.extract_32.active = (master_beat_length > 32)
                    
                    -- Auto-check available subdivisions
                    if master_beat_length > 1 then vb.views.extract_1.value = true end
                    if master_beat_length > 2 then vb.views.extract_2.value = true end
                    if master_beat_length > 4 then vb.views.extract_4.value = true end
                    if master_beat_length > 8 then vb.views.extract_8.value = true end
                    if master_beat_length > 16 then vb.views.extract_16.value = true end
                    if master_beat_length > 32 then vb.views.extract_32.value = true end
                end
            }
        },
        
        vb:space{height=5},
        
        -- Subdivision checkboxes
        vb:text{
            text = "Extract These Subdivisions",
            style = "strong", font="bold",
        },
        vb:column{
            vb:row{
                vb:checkbox{
                    id = "extract_32",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "32 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_16",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "16 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_8",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "08 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_4",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "04 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_2",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "02 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_1",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "01 beats"}
            }
        },
        
        vb:space{height=5},
        
        -- Skip silence checkbox
        vb:row{
            vb:checkbox{
                id = "skip_silence_checkbox",
                value = skip_writing_silence,
                notifier = function(value)
                    skip_writing_silence = value
                end
            },
            vb:text{text = "Do not write silence", style = "strong", font="bold"}
        },
        
        vb:space{height=5},
        
        -- Direct to Instruments mode
        vb:row{
            vb:checkbox{
                id = "direct_mode_checkbox",
                value = direct_to_instruments,
                notifier = function(value)
                    direct_to_instruments = value
                    -- Enable/disable grouping popup based on direct mode
                    if vb.views.direct_grouping_popup then
                        vb.views.direct_grouping_popup.active = value
                    end
                end
            },
            vb:text{text = "Direct to Instruments (skip WAV export)", style = "strong", font="bold"},
            vb:space{width=10},
            vb:text{text = "Grouping:"},
            vb:popup{
                id = "direct_grouping_popup",
                items = {"Per-sample", "Per-stem", "Per-beat", "All combined"},
                value = direct_grouping_mode,
                width = 100,
                active = direct_to_instruments,
                notifier = function(value)
                    direct_grouping_mode = value
                end
            }
        },
        
        -- Control buttons
        vb:row{
            vb:button{
                id = "process_button",
                text = "Start Processing",
                width = 110,
                active = false,
                notifier = startProcessing
            },
            vb:button{
                text = "Quick Load",
                width = 70,
                notifier = function()
                    onQuickLoadSlices(getOutputFolderPath(), {64,32,16,8,4,2,1}, 1)
                end
            },
            vb:button{
                text = "Load as Drumkit",
                width = 80,
                notifier = function()
                    loadAsDrumkitsFromFolder(getOutputFolderPath())
                end
            },
            vb:button{
                text = "Make Me One With Everything",
                width = 150,
                notifier = function()
                    makeEverythingFromFolder(getOutputFolderPath())
                end
            },
            vb:button{
                text = "Close",
                width = 60,
                notifier = function()
                    if process_slicer and process_slicer:running() then
                        process_slicer:cancel()
                    end
                    cleanupStemSlicerBpmObservable()
                    -- Clean up export instrument when dialog closes (CRASH PREVENTION)
                    if export_instrument_idx then
                        cleanupExportInstrument()
                    end
                    dialog:close()
                    dialog = nil
                end
            }
        }
    }
    
    local keyhandler = create_keyhandler_for_dialog(
        function() return dialog end,
        function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Stem Slicer", content, keyhandler)
    setupStemSlicerBpmObservable()
end

renoise.tool():add_keybinding{name = "Global:Paketti:Paketti StemSlicer Dialog...",invoke = pakettiStemSlicerDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Open Last StemSlicer Output...",invoke = openLastStemSlicerOutput}
