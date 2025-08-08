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
    margin=8, spacing=6,
    vb_local:text{ text="Reverse created drumkits?", style="strong" },
    unpack(rows),
    vb_local:row{
      vb_local:button{ text="Reverse", width=100, notifier=begin_reverse },
      vb_local:button{ text="Cancel", width=80, notifier=function() d:close() end }
    }
  }
  d = renoise.app():show_custom_dialog("Paketti – Reverse Drumkits", content)
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
    updateStemSlicerBpmDisplay()
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
local function updateExtractBeatLengths()
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

-- Summary dialog after processing
function showStemSlicerSummary()
  if last_output_folder == "" then return end
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

  local content = vb_local:column{
    margin = 8,
    spacing = 6,
    vb_local:text{text = "Processing complete!", style = "strong"},
    vb_local:text{text = table.concat(summary_lines, "\n"), style = "normal"},
    vb_local:space{height=6},
    vb_local:row{
      vb_local:text{text = "Grouping:", style = "normal", width = 80},
      vb_local:popup{ id = "grouping_popup", items = grouping_items, value = grouping_mode_index, width = 240 }
    },
    vb_local:space{height=6},
    vb_local:text{text = "Quick Load (per instrument):", style = "strong"},
    vb_local:row{
      spacing = 6,
      vb_local:button{ text = "Load 64", notifier = function() onQuickLoadSlices(last_output_folder, {64}, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load 32", notifier = function() onQuickLoadSlices(last_output_folder, {32}, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load 16", notifier = function() onQuickLoadSlices(last_output_folder, {16}, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load 8",  notifier = function() onQuickLoadSlices(last_output_folder, {8 }, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load 4",  notifier = function() onQuickLoadSlices(last_output_folder, {4 }, vb_local.views.grouping_popup.value) end},
      vb_local:button{ text = "Load All", notifier = function() onQuickLoadSlices(last_output_folder, {64,32,16,8,4}, vb_local.views.grouping_popup.value) end}
    },
    vb_local:space{height=6},
    vb_local:row{
      spacing = 8,
      vb_local:button{ text = "Open Output Folder", notifier = function()
        openFolderInFinder(last_output_folder)
      end},
      vb_local:button{ text = "Load All Non-Silent Slices", notifier = function()
        onQuickLoadSlices(last_output_folder, {64,32,16,8,4}, vb_local.views.grouping_popup.value)
      end}
    }
  }
  renoise.app():show_custom_dialog("PakettiStemSlicer – Finished", content)
end

-- Open folder via OS
function openFolderInFinder(path)
  if package.config:sub(1,1) == "\\" then
    os.execute(string.format('start "" "%s"', path:gsub("/", "\\")))
  else
    os.execute(string.format("open '%s'", path:gsub("'", "'\\''")))
  end
end

-- Scan output folder and load non-silent slices grouped into instruments with headers
function loadNonSilentSlicesIntoInstruments(folder)
  local files = PakettiGetFilesInDirectory(folder)
  if #files == 0 then
    renoise.app():show_status("No files found in output folder")
    print("No files found in output folder:", folder)
    return
  end
  -- Filter out silent files
  local non_silent = {}
  for _, f in ipairs(files) do
    if not f:lower():match("_silence%.") and not f:lower():match("_silent%.") then
      table.insert(non_silent, f)
    end
  end
  table.sort(non_silent)

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

-- Quick-load handler with grouping and beat filters
function onQuickLoadSlices(folder, beats_filter, grouping_mode_index)
  local files = PakettiGetFilesInDirectory(folder)
  if #files == 0 then
    renoise.app():show_status("No files to load.")
    return
  end
  -- Build map: sample_base -> beat -> {files}
  local map = {}
  for _, f in ipairs(files) do
    if not f:lower():match("_silence%.") and not f:lower():match("_silent%.") then
      local name = f:match("[^/\\]+$") or f
      local base = name:gsub("_%d%dbeats.*$", "")
      local beats = tonumber(name:match("_(%d%d)beats")) or 0
      if beats > 0 then
        map[base] = map[base] or {}
        map[base][beats] = map[base][beats] or {}
        table.insert(map[base][beats], f)
      end
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
  -- Fill zones sequentially
  local zone_index = 1
  for _, f in ipairs(take) do
    if zone_index == 1 then
      inst.samples[1].sample_buffer:load_from(f)
      local fn = (f:match("[^/\\]+$") or f):gsub("%.%w+$", "")
      inst.samples[1].name = fn
    else
      inst:insert_sample_at(zone_index)
      inst.samples[zone_index].sample_buffer:load_from(f)
      local fn = (f:match("[^/\\]+$") or f):gsub("%.%w+$", "")
      inst.samples[zone_index].name = fn
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
-- Helper function to get supported audio files from folder
local function getSupportedAudioFiles(folder_path)
    -- Use the existing PakettiGetFilesInDirectory function from main.lua
    -- which already handles cross-platform file discovery and filtering
    return PakettiGetFilesInDirectory(folder_path)
end

-- Helper: compute output folder path for current selection
local function getOutputFolderPath()
  if selected_folder == nil or selected_folder == "" then return "" end
  return selected_folder .. "/PakettiStemSlicer_Output"
end

function isSilentSlicePath(path)
  if not path or path == "" then return false end
  local p = string.lower(path)
  -- Matches ..._silence.ext, ..._silent.ext, ...-silence.ext, ... silence.ext
  return (p:match("[_%-%s]silence%.[%w]+$") ~= nil) or (p:match("_silent%.[%w]+$") ~= nil)
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

-- Calculate beat duration in frames for given BPM and sample rate
local function calculateBeatDurationFrames(bpm, sample_rate)
    return math.floor((60.0 / bpm) * sample_rate)
end

-- Detect if a slice contains mostly silence
local function detectSilence(sample_buffer, start_frame, end_frame, channels)
    local total_rms = 0
    local sample_count = 0
    
    for ch = 1, channels do
        for frame = start_frame, math.min(end_frame, sample_buffer.number_of_frames) do
            local sample_val = sample_buffer:sample_data(ch, frame)
            total_rms = total_rms + (sample_val * sample_val)
            sample_count = sample_count + 1
        end
    end
    
    if sample_count == 0 then return true end
    
    local rms = math.sqrt(total_rms / sample_count)
    return rms < SILENCE_THRESHOLD
end



-- Check if a region is silent
local function checkSilence(buffer, start_frame, end_frame)
    if not buffer or not buffer.has_sample_data then return true end
    local length = end_frame - start_frame + 1
    if length <= 0 then return true end

    -- Probe up to 10k frames spread evenly across the region for reliability
    local probes = math.min(length, 10000)
    local step = math.max(1, math.floor(length / probes))
    local total_rms = 0
    local max_abs = 0
    local count = 0

    for ch = 1, buffer.number_of_channels do
        local f = start_frame
        while f <= end_frame do
            local v = buffer:sample_data(ch, f)
            local av = math.abs(v)
            if av > max_abs then max_abs = av end
            total_rms = total_rms + (v * v)
            count = count + 1
            f = f + step
        end
    end

    if count == 0 then return true end
    local rms = math.sqrt(total_rms / count)

    -- Consider silent if both RMS and peak are very low
    if rms < SILENCE_THRESHOLD and max_abs < (SILENCE_THRESHOLD * 4) then
        return true
    end
    return false
end

-- Export a specific region of a sample buffer to wav file
local function exportSliceRegion(buffer, start_frame, end_frame, output_path)
    local success, error_msg = pcall(function()
        local slice_length = end_frame - start_frame + 1
        
        -- Create temporary sample for export
        local temp_song = renoise.song()
        local temp_inst_idx = #temp_song.instruments + 1
        temp_song:insert_instrument_at(temp_inst_idx)
        local temp_inst = temp_song.instruments[temp_inst_idx]
        temp_inst:insert_sample_at(1)
        local temp_sample = temp_inst.samples[1]
        
        -- Create buffer for the slice
        temp_sample.sample_buffer:create_sample_data(
            buffer.sample_rate, 
            buffer.bit_depth, 
            buffer.number_of_channels, 
            slice_length
        )
        
        temp_sample.sample_buffer:prepare_sample_data_changes()
        
        -- Copy the region data
        for ch = 1, buffer.number_of_channels do
            for frame = 1, slice_length do
                local source_frame = start_frame + frame - 1
                if source_frame <= end_frame then
                    temp_sample.sample_buffer:set_sample_data(ch, frame, buffer:sample_data(ch, source_frame))
                end
            end
        end
        
        temp_sample.sample_buffer:finalize_sample_data_changes()
        
        -- Export the slice
        temp_sample.sample_buffer:save_as(output_path, "wav")
        
        -- Clean up
        temp_song:delete_instrument_at(temp_inst_idx)
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

-- Process a single audio file using direct visual approach
local function processSingleFile(file_path, output_folder)
    print("Processing file:", file_path)
    
    local song = renoise.song()
    local clean_name = getCleanFilename(file_path)
    local file_ext = getFileExtension(file_path)
    
    current_progress = string.format("Loading %s into Renoise...", clean_name)
    coroutine.yield()
    
    -- Step 1: Load sample into Renoise (new instrument)
    local original_inst_count = #song.instruments
    local new_inst_idx = original_inst_count + 1
    song:insert_instrument_at(new_inst_idx)
    song.selected_instrument_index = new_inst_idx
    local new_inst = song.instruments[new_inst_idx]
    new_inst.name = clean_name
    
    new_inst:insert_sample_at(1)
    song.selected_sample_index = 1
    local sample = new_inst.samples[1]
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
        song:delete_instrument_at(new_inst_idx)
        return false
    end
    
    local buffer = sample.sample_buffer
    local sample_rate = buffer.sample_rate
    local total_frames = buffer.number_of_frames
    
    print(string.format("  Loaded into instrument %d: %d Hz, %d frames", new_inst_idx, sample_rate, total_frames))
    
    -- Step 2: Add slice markers for master beat length
    current_progress = string.format("Adding %d-beat slice markers...", master_beat_length)
    coroutine.yield()
    
    local beat_duration_frames = calculateBeatDurationFrames(target_bpm, sample_rate)
    local master_slice_frames = beat_duration_frames * master_beat_length
    local num_master_slices = math.floor(total_frames / master_slice_frames)
    
    print(string.format("  Adding %d slice markers every %d frames (%d beats)", num_master_slices, master_slice_frames, master_beat_length))
    
    -- Clear existing markers and add new ones
    while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
    end
    
    for slice_idx = 1, num_master_slices do
        local slice_start = (slice_idx - 1) * master_slice_frames + 1
        if slice_start <= total_frames then
            sample:insert_slice_marker(slice_start)
        end
    end
    
    -- Step 3: Save master beat slices directly from sample editor with visual selection
    current_progress = string.format("Exporting %d-beat slices...", master_beat_length)
    coroutine.yield()
    
    local slice_positions = {1} -- Start with beginning
    for i = 1, #sample.slice_markers do
        table.insert(slice_positions, sample.slice_markers[i])
    end
    table.insert(slice_positions, total_frames + 1) -- End marker
    
    -- Export master beat slices
    for slice_idx = 1, #slice_positions - 1 do
        local slice_start = slice_positions[slice_idx]
        local slice_end = slice_positions[slice_idx + 1] - 1
        local slice_length = slice_end - slice_start + 1
        
        if slice_length > 0 then
            -- Visual selection in sample editor
            buffer.selection_start = slice_start
            buffer.selection_end = slice_end
            
            current_progress = string.format("Exporting %s: %d-beat slice %d/%d", 
                clean_name, master_beat_length, slice_idx, #slice_positions - 1)
            renoise.app():show_status(current_progress)
            
            -- Check for silence
            local is_silent = checkSilence(buffer, slice_start, slice_end)
            local silence_suffix = is_silent and "_silence" or ""
            
            -- Export this slice
            local output_filename = string.format("%s_%02dbeats_slice%02d%s.%s", 
                clean_name, master_beat_length, slice_idx, silence_suffix, file_ext)
            local output_path = output_folder .. "/" .. output_filename
            
            local export_success = exportSliceRegion(buffer, slice_start, slice_end, output_path)
            if export_success then
                print(string.format("    Exported: %s", output_filename))
            else
                local export_error = string.format("    Failed to export: %s", output_filename)
                print(export_error)
                renoise.app():show_status(export_error)
            end
            
            coroutine.yield()
        end
    end
    
    -- Step 4: Now create subdivisions from the master slices
    for _, beat_length in ipairs(extract_beat_lengths) do
        if beat_length < master_beat_length then
            local subdivisions_per_master = master_beat_length / beat_length
            
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
                        
                        -- Check for silence
                        local is_silent = checkSilence(buffer, sub_start, sub_end)
                        local silence_suffix = is_silent and "_silence" or ""
                        
                        -- Export subdivision
                        local output_filename = string.format("%s_%02dbeats_slice%02d%s.%s", 
                            clean_name, beat_length, overall_slice_num, silence_suffix, file_ext)
                        local output_path = output_folder .. "/" .. output_filename
                        
                        local export_success = exportSliceRegion(buffer, sub_start, sub_end, output_path)
                        if export_success then
                            print(string.format("    Exported: %s", output_filename))
                        else
                            local export_error = string.format("    Failed to export: %s", output_filename)
                            print(export_error)
                            renoise.app():show_status(export_error)
                        end
                        
                        if overall_slice_num % 3 == 0 then
                            coroutine.yield()
                        end
                    end
                end
            end
        end
    end
    
    print(string.format("  Completed processing: %s", clean_name))
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
    
    -- Process each file
    for file_idx, file_path in ipairs(audio_files) do
        if process_slicer and process_slicer:was_cancelled() then
            print("Processing cancelled by user")
            break
        end
        
        current_progress = string.format("Processing file %d/%d: %s", file_idx, #audio_files, getCleanFilename(file_path))
        processSingleFile(file_path, output_folder)
        coroutine.yield() -- Allow UI updates
    end
    
    current_progress = "Processing complete!"
    print("=== Processing Complete ===")
    renoise.app():show_status(string.format("PakettiStemSlicer: Processed %d files", #audio_files))
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
            vb.views.folder_display.text = string.format("Folder: %s (%d files)", folder_path, #audio_files)
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
    
    -- Create and start ProcessSlicer
    process_slicer = ProcessSlicer(processAllFiles)
    local progress_dialog, progress_vb = process_slicer:create_dialog("PakettiStemSlicer Processing...")
    
    -- Update progress text periodically
    local progress_timer = renoise.tool():add_timer(function()
        if progress_dialog and progress_dialog.visible and progress_vb then
            progress_vb.views.progress_text.text = current_progress
        end
        
        if not process_slicer:running() then
            renoise.tool():remove_timer(progress_timer)
            if progress_dialog and progress_dialog.visible then progress_dialog:close() end
            -- Show summary dialog when done
            showStemSlicerSummary()
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
        
        
        -- Folder selection
        vb:button{text="Browse Folder",width=100,notifier = browseForFolder},
        
        vb:text{id="folder_display",text="No folder selected",width=400,style="normal"},
        -- BPM input
        vb:row{
            vb:text{
                text = "Target BPM:",
                width = 80
            },
            vb:valuebox{
                id = "bpm_input",
                value = target_bpm,
                min = 1,
                max = 999,
                notifier = function(value)
                    target_bpm = value
                end
            }
        },
        
        vb:space{height=8},
        
        -- Master beat length selection
        vb:text{
            text = "Master Slice Size:",
            style = "strong"
        },
        vb:row{
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
            text = "Extract These Subdivisions:",
            style = "strong"
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
                vb:text{text = "8 beats"}
            },
            vb:row{
                vb:checkbox{
                    id = "extract_4",
                    value = true,
                    notifier = function(value)
                        updateExtractBeatLengths()
                    end
                },
                vb:text{text = "4 beats"}
            }
        },
        
        vb:space{height=8},
        
        vb:text{
            text = "Naming format: originalname_XXbeats_sliceYY.wav",
            style = "normal"
        },
        
        vb:text{
            text = "Silent slices will be marked with _silence suffix",
            style = "normal"
        },
    
        -- Control buttons
        vb:row{
            spacing = 8,
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
    dialog = renoise.app():show_custom_dialog("PakettiStemSlicer", content, keyhandler)
    setupStemSlicerBpmObservable()
end

renoise.tool():add_menu_entry{name = "Main Menu:Tools:Paketti..:Other..:PakettiStemSlicer...",invoke = pakettiStemSlicerDialog}
renoise.tool():add_keybinding{name = "Global:Paketti:PakettiStemSlicer Dialog...",invoke = pakettiStemSlicerDialog}
