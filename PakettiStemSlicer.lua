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
local ALL_BEAT_LENGTHS = {4, 8, 16, 32, 64}
local SILENCE_THRESHOLD = 0.001 -- RMS threshold for silence detection
local SUPPORTED_FORMATS = {"*.wav", "*.aif", "*.aiff", "*.flac"}

-- User-configurable options
local master_beat_length = 64  -- The base slice size to create first
local extract_beat_lengths = {32, 16, 8, 4}  -- Which subdivisions to extract

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
    song:insert_instrument_at(export_instrument_idx)
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
            completion_text = completion_text .. string.format("\nOUTPUT: %s", last_output_folder or "Unknown")
            vb.views.folder_display.text = completion_text
            vb.views.folder_display.style = "strong" -- Make it prominent
        end
        
        -- Repurpose the "Browse Folder" button to "Open Output Folder" 
        if last_output_folder then
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
    
    -- CIRCUIT BREAKER: Stop infinite error flooding
    if consecutive_errors > 5 then
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
    -- Sort from largest to smallest
    table.sort(extract_beat_lengths, function(a, b) return a > b end)
end

-- Summary dialog after processing (WITH EMERGENCY FLOOD PREVENTION)
function showStemSlicerSummary()
  if last_output_folder == "" then return end
  
  -- EMERGENCY: Prevent dialog flooding
  if not preventDialogFlooding("completion") then
    print("EMERGENCY: Blocked completion dialog due to flooding")
    return -- Don't show dialog
  end
  local vb_local = renoise.ViewBuilder()
  local summary_lines = {
    string.format("Exported folder: %s", last_selected_folder),
    string.format("Output folder: %s", last_output_folder),
    string.format("BPM: %.2f", last_bpm_used),
    string.format("Master: %d beats", last_master_beat)
  }
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

  local content = vb_local:column{
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
      vb_local:button{ text = "Load 4",  notifier = function() onQuickLoadSlices(last_output_folder, {4 }, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load All", notifier = function() onQuickLoadSlices(last_output_folder, {64,32,16,8,4}, vb_local.views.grouping_popup.value) end}
    },
    vb_local:space{height=6},
    vb_local:row{
      vb_local:button{ text = "Open Output Folder", notifier = function()
        openFolderInFinder(last_output_folder)
      end},
      vb_local:button{ text = "Load All Non-Silent Slices", notifier = function()
        onQuickLoadSlices(last_output_folder, {64,32,16,8,4}, vb_local.views.grouping_popup.value)
      end}
    }
  }
  renoise.app():show_custom_dialog("PakettiStemSlicer - Finished", content)
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
    song:insert_instrument_at(idx)
    song.selected_instrument_index = idx
    pakettiPreferencesDefaultInstrumentLoader()
    local inst = song:instrument(idx)
    inst.name = title
    return idx
  end

  -- Load grouped: per sample -> descending beats
  for sample_base, beats_table in pairs(by_sample_then_beats) do
    insert_header_instrument(string.format("== %s =", sample_base))
    local ordered_beats = {64,32,16,8,4}
    for _, beats in ipairs(ordered_beats) do
      if beats_table[beats] then
        insert_header_instrument(string.format("== %02d Beats of %s ==", beats, sample_base))
        for _, filepath in ipairs(beats_table[beats]) do
          local next_idx = song.selected_instrument_index + 1
          song:insert_instrument_at(next_idx)
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

  local ordered_beats = {64,32,16,8,4}
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

  local per_beat = { [4]={}, [8]={}, [16]={}, [32]={}, [64]={} }
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

  local ordered_beats = {4,8,16,32,64}
  local per_beat_tasks = {}
  -- Summary header before all-samples drumkits
  table.insert(per_beat_tasks, {kind="header", title="== All Samples Drumkit (64, 32, 16, 08, 04) =="})
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
  local max_zones = 120
  table.sort(file_list)
  local take = {}
  for i=1, math.min(#file_list, max_zones) do table.insert(take, file_list[i]) end
  if #take == 0 then return end

  -- Load default drumkit template and then fill zones by loading samples into instrument
  local song = renoise.song()
  local idx = song.selected_instrument_index + 1
  song:insert_instrument_at(idx)
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
end

-- Make-everything workflow
function makeEverythingFromFolder(folder)
  -- 1) Combined drumkits per beats and all-beats combined
  loadAsDrumkitsFromFolder(folder)
  -- 2) Then per-sample instrument groupings using default XRNI, one slice/instrument
  onQuickLoadSlices(folder, {64,32,16,8,4}, 1)
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
  song:insert_instrument_at(idx)
  song.selected_instrument_index = idx
  -- Do NOT pakettify the header; keep it empty without samples
  local inst = song:instrument(idx)
  inst.name = title
  return idx
end

function loadFilesAsInstruments(file_list)
  local song = renoise.song()
  table.sort(file_list)
  for _, filepath in ipairs(file_list) do
    local idx = song.selected_instrument_index + 1
    song:insert_instrument_at(idx)
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
        song:insert_instrument_at(idx)
        song.selected_instrument_index = idx
        pakettiPreferencesDefaultInstrumentLoader()
        local inst = song:instrument(idx)
        inst.name = t.path:match("[^/\\]+$") or t.path
        if #inst.samples == 0 then inst:insert_sample_at(1) end
        song.selected_sample_index = 1
        inst.samples[1].sample_buffer:load_from(t.path)
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
      local set1 = instrument.sample_modulation_sets[1]
      if set1 and set1.devices and #set1.devices >= 2 and set1.devices[2] then
        set1.devices[2].is_active = true
      end
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
    song:insert_instrument_at(new_inst_idx)
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
            
            local output_filename = string.format("%s_%02dbeats_slice%02d%s.wav", 
                clean_name, master_beat_length, slice_idx, silence_suffix)
            local output_path = output_folder .. "/" .. output_filename
            
            local export_success = false
            local export_error_msg = ""
            
            print(string.format("EXPORT DEBUG [%s]: About to export slice %d, silent=%s, filename=%s", 
                file_name, slice_idx, tostring(is_silent), output_filename))
            
            if is_silent then
                -- OPTIMIZATION: Copy pre-generated silence file instead of exporting
                local silence_source = generateSilenceFile(master_beat_length, sample_rate, output_folder)
                export_success = copySilenceFile(silence_source, output_path)
                if export_success then
                    print(string.format("EXPORT SUCCESS [%s]: Copied silence: %s", file_name, output_filename))
                else
                    export_error_msg = string.format("Failed to copy silence: %s", output_filename)
                    print(string.format("EXPORT FAILED [%s]: %s", file_name, export_error_msg))
                end
            else
                -- Export actual audio slice
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
                        
                        local output_filename = string.format("%s_%02dbeats_slice%02d%s.wav", 
                            clean_name, beat_length, overall_slice_num, silence_suffix)
                        local output_path = output_folder .. "/" .. output_filename
                        
                        local export_success = false
                        if is_silent then
                            -- OPTIMIZATION: Copy pre-generated silence file instead of exporting
                            local silence_source = generateSilenceFile(beat_length, sample_rate, output_folder)
                            export_success = copySilenceFile(silence_source, output_path)
                            if export_success then
                                print(string.format("    Copied silence: %s", output_filename))
                            else
                                print(string.format("    Failed to copy silence: %s", output_filename))
                            end
                        else
                            -- Export actual audio subdivision
                            export_success = exportSliceRegion(buffer, sub_start, sub_end, output_path)
                            if export_success then
                                print(string.format("    Exported: %s", output_filename))
                            else
                                local export_error = string.format("    Failed to export: %s", output_filename)
                                print(export_error)
                                renoise.app():show_status(export_error)
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
    
    -- Initialize progress and error tracking (OPTIMIZATION)
    files_completed = 0
    total_files_to_process = #audio_files
    current_sample_name = "Starting..."
    clearErrorTracking()
    resetDialogFloodPrevention() -- Reset dialog flood prevention for new session
    
    -- Initialize memory leak prevention (CRITICAL)
    resetMemoryTracking()
    print("MEMORY: Started with garbage collection and memory tracking")
    
    -- Create output folder
    local output_folder = selected_folder .. "/PakettiStemSlicer_Output"
    
    -- Create output directory using OS-specific command
    local mkdir_cmd
    if package.config:sub(1,1) == "\\" then  -- Windows
        mkdir_cmd = string.format('mkdir "%s" 2>nul', output_folder:gsub("/", "\\"))
    else  -- macOS and Linux
        mkdir_cmd = string.format("mkdir -p '%s'", output_folder:gsub("'", "'\\''"))
    end
    os.execute(mkdir_cmd)
    
    print(string.format("=== PakettiStemSlicer Processing ==="))
    print(string.format("Input folder: %s", selected_folder))
    print(string.format("Output folder: %s", output_folder))
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
            logProcessingError("CRITICAL", "", "Too many critical errors, stopping processing")
            
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

-- Browse for folder containing audio files
local function browseForFolder()
    local folder_path = renoise.app():prompt_for_path("Select Folder Containing Audio Files")
    if folder_path and folder_path ~= "" then
        selected_folder = folder_path
        audio_files = getSupportedAudioFiles(folder_path)
        
        if dialog and dialog.visible then
            vb.views.folder_display.text = string.format("%s (%d files)", folder_path, #audio_files)
            vb.views.process_button.active = #audio_files > 0
        end
        
        renoise.app():show_status(string.format("Selected folder with %d audio files", #audio_files))
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
        -- Run the main processing function
        processAllFiles()
        
        -- Ensure cleanup happens after processing completes normally
        if export_instrument_idx then
            print("NORMAL COMPLETION: Final cleanup of temp export instrument")
            cleanupExportInstrument()
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
          text = "Naming format: originalname_XXbeats_sliceYY.wav, silent slices will be marked with _silence suffix",
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
                items = {"4 beats", "8 beats", "16 beats", "32 beats", "64 beats"},
                value = 5, -- Default to 64 beats
                width = 100,
                notifier = function(index)
                    master_beat_length = ALL_BEAT_LENGTHS[index]
                    -- Update subdivision checkboxes availability
                    vb.views.extract_4.active = (master_beat_length > 4)
                    vb.views.extract_8.active = (master_beat_length > 8)
                    vb.views.extract_16.active = (master_beat_length > 16)
                    vb.views.extract_32.active = (master_beat_length > 32)
                    
                    -- Auto-check available subdivisions
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
            }
        },  
        -- Control buttons
        vb:row{
            vb:button{
                id = "process_button",
                text = "Start Processing",
                width = 120,
                active = false,
                notifier = startProcessing
            },
            vb:button{
                text = "Quick Load",
                width = 100,
                notifier = function()
                    onQuickLoadSlices(getOutputFolderPath(), {64,32,16,8,4}, 1)
                end
            },
            vb:button{
                text = "Load as Drumkit",
                width = 120,
                notifier = function()
                    loadAsDrumkitsFromFolder(getOutputFolderPath())
                end
            },
            vb:button{
                text = "Make Me One With Everything",
                width = 220,
                notifier = function()
                    makeEverythingFromFolder(getOutputFolderPath())
                end
            },
            vb:button{
                text = "Close",
                width = 80,
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

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti Gadgets:Paketti Stem Slicer...",invoke = pakettiStemSlicerDialog}
renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti..:Other..:Open Last Stem Slicer Output...",invoke = openLastStemSlicerOutput}
renoise.tool():add_keybinding{name = "Global:Paketti:Paketti Stem Slicer Dialog...",invoke = pakettiStemSlicerDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:Open Last Stem Slicer Output...",invoke = openLastStemSlicerOutput}
