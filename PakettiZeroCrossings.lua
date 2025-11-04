-- PakettiZeroCrossings.lua
-- Advanced slice functionality with zero-crossing detection, randomization, and BPM-based movement
-- Combines wipe & slice with zero crossing snap for clean cuts

-- Zero-Crossing Detection Function (from PakettiBeatDetect.lua - most robust implementation)
function PakettiZeroCrossingsFind(buffer, pos, search_range_samples, zero_threshold)
  local start_pos = math.max(1, pos - search_range_samples)
  local end_pos = math.min(buffer.number_of_frames, pos + search_range_samples)

  local zero_crossing_pos = pos
  local min_amplitude = math.abs(buffer:sample_data(1, pos))

  -- Search backward for zero crossing
  for i = pos, start_pos, -1 do
    local sample_value = buffer:sample_data(1, i)
    if math.abs(sample_value) <= zero_threshold then
      zero_crossing_pos = i
      break
    elseif math.abs(sample_value) < min_amplitude then
      min_amplitude = math.abs(sample_value)
      zero_crossing_pos = i
    end
  end

  -- Search forward if not found backward
  if zero_crossing_pos == pos then
    for i = pos, end_pos do
      local sample_value = buffer:sample_data(1, i)
      if math.abs(sample_value) <= zero_threshold then
        zero_crossing_pos = i
        break
      elseif math.abs(sample_value) < min_amplitude then
        min_amplitude = math.abs(sample_value)
        zero_crossing_pos = i
      end
    end
  end

  return zero_crossing_pos
end

-- Core Wipe & Slice function with Zero Crossing Snap
function PakettiZeroCrossingsWipeSlice(slice_count, use_zero_crossing, zero_crossing_sensitivity)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Limit slice count to 255 (Renoise's maximum)
  if slice_count > 255 then
    print("-- Zero Crossing Wipe&Slice: Limited slice count from " .. slice_count .. " to 255 (Renoise maximum)")
    renoise.app():show_status("Limited to 255 slices (Renoise maximum)")
    slice_count = 255
  end

  local s = renoise.song()
  local currInst = s.selected_instrument_index

  -- Check if the instrument has samples
  if #s.instruments[currInst].samples == 0 then
    renoise.app():show_status("No samples available in the selected instrument.")
    return false
  end

  s.selected_sample_index = 1
  local currSamp = s.selected_sample_index
  
  -- Check for sample count vs slice markers
  local first_sample = s.instruments[currInst].samples[1]
  local has_slice_markers = first_sample.slice_markers and #first_sample.slice_markers > 0
  local sample_count = #s.instruments[currInst].samples
  
  -- If no slice markers and more than one sample, show error and return
  if not has_slice_markers and sample_count > 1 then
    renoise.app():show_status("Zero Crossing Wipe & Slice detected more than one sample, doing nothing.")
    return false
  end

  local buffer = first_sample.sample_buffer
  if not buffer.has_sample_data then
    renoise.app():show_status("Sample buffer is empty.")
    return false
  end

  -- Store original values
  local beatsync_lines = nil
  local dontsync = nil
  if first_sample.beat_sync_enabled then
    beatsync_lines = first_sample.beat_sync_lines
  else
    dontsync = true
    beatsync_lines = 0
  end
  local currentTranspose = s.selected_sample.transpose

  -- Clear existing slice markers from the first sample (wipe slices)
  for i = #first_sample.slice_markers, 1, -1 do
    first_sample:delete_slice_marker(first_sample.slice_markers[i])
  end

  -- Calculate basic slice positions
  local frame_count = buffer.number_of_frames
  local slice_distance = frame_count / slice_count
  local slice_positions = {}
  
  -- Insert first slice marker at position 1
  first_sample:insert_slice_marker(1)
  table.insert(slice_positions, 1)

  -- Calculate and optionally snap slice positions to zero crossings
  for i = 1, slice_count - 1 do
    local basic_position = math.floor(slice_distance * i)
    local final_position = basic_position
    
    if use_zero_crossing then
      -- Convert sensitivity percentage to amplitude threshold
      local zero_threshold = (zero_crossing_sensitivity or 1.0) / 100
      local search_range = math.floor(buffer.sample_rate * 0.01) -- 10ms search range
      
      final_position = PakettiZeroCrossingsFind(buffer, basic_position, search_range, zero_threshold)
    end
    
    first_sample:insert_slice_marker(final_position)
    table.insert(slice_positions, final_position)
  end

  -- Apply settings to all samples created by the slicing (from original slicerough)
  for i, sample in ipairs(s.instruments[currInst].samples) do
    sample.new_note_action = preferences.WipeSlices.WipeSlicesNNA.value
    sample.oneshot = preferences.WipeSlices.WipeSlicesOneShot.value
    sample.autoseek = preferences.WipeSlices.WipeSlicesAutoseek.value
    sample.autofade = preferences.WipeSlices.WipeSlicesAutofade.value
    sample.loop_release = preferences.WipeSlices.WipeSlicesLoopRelease.value
    sample.mute_group = preferences.WipeSlices.WipeSlicesMuteGroup.value
    sample.transpose = currentTranspose
    
    if preferences.WipeSlices.WipeSlicesBeatSyncGlobal.value == true then
      sample.beat_sync_enabled = true
      sample.beat_sync_lines = preferences.WipeSlices.WipeSlicesBeatSyncMode.value
    else
      if dontsync == nil then
        sample.beat_sync_enabled = true
        sample.beat_sync_lines = beatsync_lines
      else
        sample.beat_sync_enabled = false
      end
    end
  end

  renoise.app():show_status("Zero Crossing Wipe & Slice: Created " .. slice_count .. " slices" .. 
    (use_zero_crossing and " with zero-crossing snap" or ""))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
  
  return true
end

-- Randomize existing slice positions
function PakettiZeroCrossingsRandomizeSlices(randomization_amount, use_zero_crossing, zero_crossing_sensitivity)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    return
  end

  local buffer = sample.sample_buffer
  local slice_markers = sample.slice_markers
  
  if #slice_markers == 0 then
    renoise.app():show_status("No slice markers found to randomize")
    return
  end

  -- Convert randomization amount to actual frame range
  local max_randomization = math.floor((randomization_amount / 100) * (buffer.number_of_frames / #slice_markers))
  
  -- Store original positions and create randomized versions
  local original_positions = {}
  local new_positions = {}
  
  for i, marker_pos in ipairs(slice_markers) do
    table.insert(original_positions, marker_pos)
    
    -- Calculate random offset
    local random_offset = math.random(-max_randomization, max_randomization)
    local new_pos = math.max(1, math.min(buffer.number_of_frames, marker_pos + random_offset))
    
    if use_zero_crossing then
      local zero_threshold = (zero_crossing_sensitivity or 1.0) / 100
      local search_range = math.floor(buffer.sample_rate * 0.01) -- 10ms search range
      new_pos = PakettiZeroCrossingsFind(buffer, new_pos, search_range, zero_threshold)
    end
    
    table.insert(new_positions, new_pos)
  end
  
  -- Delete old markers and insert new ones
  for i = #slice_markers, 1, -1 do
    sample:delete_slice_marker(slice_markers[i])
  end
  
  -- Sort new positions to avoid overlap issues
  table.sort(new_positions)
  
  for _, pos in ipairs(new_positions) do
    sample:insert_slice_marker(pos)
  end
  
  renoise.app():show_status("Randomized " .. #new_positions .. " slice positions (±" .. randomization_amount .. "%)")
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Put random slices distributed along the sample
function PakettiZeroCrossingsRandomDistributedSlices(min_slices, max_slices, use_zero_crossing, zero_crossing_sensitivity)
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    return
  end

  local buffer = sample.sample_buffer
  
  -- Clear existing slice markers
  for i = #sample.slice_markers, 1, -1 do
    sample:delete_slice_marker(sample.slice_markers[i])
  end
  
  -- Determine random number of slices
  local slice_count = math.random(min_slices, math.min(max_slices, 255))
  
  -- Create random positions distributed across the sample
  local positions = {}
  local frame_count = buffer.number_of_frames
  
  -- Always add position 1
  table.insert(positions, 1)
  
  -- Generate random positions
  for i = 2, slice_count do
    local random_pos = math.random(2, frame_count - 1)
    table.insert(positions, random_pos)
  end
  
  -- Sort positions to ensure proper order
  table.sort(positions)
  
  -- Apply zero crossing snap if requested
  if use_zero_crossing then
    local zero_threshold = (zero_crossing_sensitivity or 1.0) / 100
    local search_range = math.floor(buffer.sample_rate * 0.01) -- 10ms search range
    
    for i = 1, #positions do
      positions[i] = PakettiZeroCrossingsFind(buffer, positions[i], search_range, zero_threshold)
    end
    
    -- Re-sort after zero crossing adjustment
    table.sort(positions)
  end
  
  -- Insert slice markers
  for _, pos in ipairs(positions) do
    sample:insert_slice_marker(pos)
  end
  
  renoise.app():show_status("Created " .. slice_count .. " random distributed slices" .. 
    (use_zero_crossing and " with zero-crossing snap" or ""))
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Calculate frame offset for BPM-based movement
function PakettiZeroCrossingsBPMToFrames(bpm, beat_fraction, sample_rate)
  -- beat_fraction: 0.25 = 1/4 beat, 0.125 = 1/8 beat, etc.
  local seconds_per_beat = 60.0 / bpm
  local seconds_offset = seconds_per_beat * beat_fraction
  return math.floor(seconds_offset * sample_rate)
end

-- Move slice start by beat fractions
function PakettiZeroCrossingsMoveSliceStart(beat_fraction, direction)
  -- direction: 1 for forward, -1 for backward
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    return
  end

  local buffer = sample.sample_buffer
  local bpm = s.transport.bpm
  local frame_offset = PakettiZeroCrossingsBPMToFrames(bpm, beat_fraction, buffer.sample_rate) * direction
  
  -- Get current loop start (or use 1 if no loop)
  local current_start = sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and sample.loop_start or 1
  local new_start = math.max(1, math.min(buffer.number_of_frames, current_start + frame_offset))
  
  -- Apply the new start position
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    sample.loop_start = new_start
  else
    -- If no loop, we can't really move "start", so show a message
    renoise.app():show_status("Sample has no loop - cannot move start position")
    return
  end
  
  local direction_text = direction > 0 and "forward" or "backward"
  local beat_text = string.format("1/%d", math.floor(1 / beat_fraction))
  renoise.app():show_status(string.format("Moved slice start %s by %s beat (%d frames)", 
    direction_text, beat_text, math.abs(frame_offset)))
end

-- Move slice end by beat fractions
function PakettiZeroCrossingsMoveSliceEnd(beat_fraction, direction)
  -- direction: 1 for forward, -1 for backward
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    return
  end

  local buffer = sample.sample_buffer
  local bpm = s.transport.bpm
  local frame_offset = PakettiZeroCrossingsBPMToFrames(bpm, beat_fraction, buffer.sample_rate) * direction
  
  -- Get current loop end (or use buffer length if no loop)
  local current_end = sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF and sample.loop_end or buffer.number_of_frames
  local new_end = math.max(1, math.min(buffer.number_of_frames, current_end + frame_offset))
  
  -- Apply the new end position
  if sample.loop_mode ~= renoise.Sample.LOOP_MODE_OFF then
    sample.loop_end = new_end
  else
    renoise.app():show_status("Sample has no loop - cannot move end position")
    return
  end
  
  local direction_text = direction > 0 and "forward" or "backward"
  local beat_text = string.format("1/%d", math.floor(1 / beat_fraction))
  renoise.app():show_status(string.format("Moved slice end %s by %s beat (%d frames)", 
    direction_text, beat_text, math.abs(frame_offset)))
end

-- Snap current selection range to nearest zero crossings
function PakettiZeroCrossingsSnapSelection(zero_crossing_sensitivity)
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("No sample selected or sample has no data")
    return
  end

  local buffer = sample.sample_buffer
  
  -- Check if there's a selection
  if buffer.selection_start == 0 and buffer.selection_end == 0 then
    renoise.app():show_status("No selection range to snap")
    return
  end
  
  local zero_threshold = (zero_crossing_sensitivity or 1.0) / 100
  local search_range = math.floor(buffer.sample_rate * 0.01) -- 10ms search range
  
  local original_start = buffer.selection_start
  local original_end = buffer.selection_end
  
  -- Find zero crossings for both start and end
  local new_start = PakettiZeroCrossingsFind(buffer, original_start, search_range, zero_threshold)
  local new_end = PakettiZeroCrossingsFind(buffer, original_end, search_range, zero_threshold)
  
  -- Make sure start is before end
  if new_start >= new_end then
    renoise.app():show_status("Could not find valid zero crossing positions")
    return
  end
  
  -- Apply the new selection
  buffer.selection_start = new_start
  buffer.selection_end = new_end
  
  local start_moved = math.abs(new_start - original_start)
  local end_moved = math.abs(new_end - original_end)
  
  renoise.app():show_status(string.format("Snapped selection to zero crossings (moved start: %d, end: %d frames)", 
    start_moved, end_moved))
end

-- Auto-zero-crossing observable management
local PakettiZeroCrossingsSelectionObservable = nil
local PakettiZeroCrossingsIsAdjusting = false

function PakettiZeroCrossingsAttachSelectionObservable()
  local s = renoise.song()
  local sample = s.selected_sample
  
  if not sample or not sample.sample_buffer.has_sample_data then
    return
  end
  
  local buffer = sample.sample_buffer
  
  -- Remove existing observable if any
  if PakettiZeroCrossingsSelectionObservable then
    PakettiZeroCrossingsSelectionObservable:remove_notifier(PakettiZeroCrossingsSelectionObservable)
    PakettiZeroCrossingsSelectionObservable = nil
  end
  
  -- Add new observable
  PakettiZeroCrossingsSelectionObservable = buffer.selection_range_observable:add_notifier(function()
    -- Don't create feedback loops
    if PakettiZeroCrossingsIsAdjusting then
      return
    end
    
    -- Check if preference is enabled
    if not preferences.ZeroCrossings.AutoSnapSelection.value then
      return
    end
    
    -- Only auto-snap if there's a selection
    if buffer.selection_start == 0 and buffer.selection_end == 0 then
      return
    end
    
    -- Set flag to prevent recursive calls
    PakettiZeroCrossingsIsAdjusting = true
    
    local zero_threshold = 0.01 -- 1% default
    local search_range = math.floor(buffer.sample_rate * 0.01) -- 10ms search range
    
    local original_start = buffer.selection_start
    local original_end = buffer.selection_end
    
    -- Find zero crossings
    local new_start = PakettiZeroCrossingsFind(buffer, original_start, search_range, zero_threshold)
    local new_end = PakettiZeroCrossingsFind(buffer, original_end, search_range, zero_threshold)
    
    -- Only apply if valid range
    if new_start < new_end then
      buffer.selection_start = new_start
      buffer.selection_end = new_end
    end
    
    -- Clear flag
    PakettiZeroCrossingsIsAdjusting = false
  end)
end

-- Handler for new document
function PakettiZeroCrossingsNewDocumentHandler()
  local s = renoise.song()
  if not s.selected_sample_observable:has_notifier(PakettiZeroCrossingsAttachSelectionObservable) then
    s.selected_sample_observable:add_notifier(PakettiZeroCrossingsAttachSelectionObservable)
  end
  PakettiZeroCrossingsAttachSelectionObservable()
end

-- Attach observable when sample changes
function PakettiZeroCrossingsInitAutoSnap()
  if not renoise.tool().app_new_document_observable:has_notifier(PakettiZeroCrossingsNewDocumentHandler) then
    renoise.tool().app_new_document_observable:add_notifier(PakettiZeroCrossingsNewDocumentHandler)
  end
  
  -- Initialize for current song (safely check if song exists)
  local song_available, s = pcall(function() return renoise.song() end)
  if song_available and s then
    if not s.selected_sample_observable:has_notifier(PakettiZeroCrossingsAttachSelectionObservable) then
      s.selected_sample_observable:add_notifier(PakettiZeroCrossingsAttachSelectionObservable)
    end
    PakettiZeroCrossingsAttachSelectionObservable()
  end
end

local PakettiZeroCrossingsDialog = nil

-- Interactive dialog for advanced slice operations
function PakettiZeroCrossingsAdvancedDialog()
  if PakettiZeroCrossingsDialog then
    PakettiZeroCrossingsDialog:close()
    PakettiZeroCrossingsDialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local DEFAULT_DIALOG_MARGIN = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN
  local DEFAULT_CONTROL_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

  local dialog_content = vb:column {
--    margin = DEFAULT_DIALOG_MARGIN,
--    spacing = DEFAULT_CONTROL_SPACING,
    
    vb:column {width=300,
      style = "group",
      --margin = DEFAULT_DIALOG_MARGIN,
      
      vb:text { text = "Wipe & Slice with Zero Crossing Snap",style="strong",font="bold", },
      
      vb:row {
        vb:text { text = "Slices:" },
        vb:valuebox { id = "slice_count", min = 2, max = 255, value = 16 },
        vb:checkbox { id = "use_zero_crossing", value = true },
        vb:text { text = "Zero Crossing Snap" },
      },
      
      vb:row {
        vb:text { text = "Sensitivity:" },
        vb:slider { id = "zero_sensitivity", min = 0.1, max = 10, value = 1.0 },
        vb:text { text = "%" },
      },
      
      vb:button {
        text = "Wipe & Slice",
        width = 300,
        notifier = function()
          PakettiZeroCrossingsWipeSlice(
            vb.views.slice_count.value,
            vb.views.use_zero_crossing.value,
            vb.views.zero_sensitivity.value
          )
        end
      },
    },
    
    vb:column {
      style = "group",
      width=300,
      --margin = DEFAULT_DIALOG_MARGIN,
      
      vb:text { text = "Randomize Existing Slices",style="strong",font="bold", },
      
      vb:row {
        vb:text { text = "Amount:" },
        vb:slider { id = "random_amount", min = 1, max = 50, value = 10 },
        vb:text { text = "%" },
      },
      
      vb:button {
        text = "Randomize Slices",
        width = 300,
        notifier = function()
          PakettiZeroCrossingsRandomizeSlices(
            vb.views.random_amount.value,
            vb.views.use_zero_crossing.value,
            vb.views.zero_sensitivity.value
          )
        end
      },
    },
    
    vb:column {
      width=300,
      style = "group",
      --margin = DEFAULT_DIALOG_MARGIN,
      
      vb:text { text = "Random Distributed Slices",style="strong",font="bold", },
      
      vb:row {
        vb:text { text = "Min:" },
        vb:valuebox { id = "min_random_slices", min = 2, max = 100, value = 8 },
        vb:text { text = "Max:" },
        vb:valuebox { id = "max_random_slices", min = 2, max = 255, value = 32 },
      },
      
      vb:button {
        text = "Create Random Slices",
        width = 300,
        notifier = function()
          PakettiZeroCrossingsRandomDistributedSlices(
            vb.views.min_random_slices.value,
            vb.views.max_random_slices.value,
            vb.views.use_zero_crossing.value,
            vb.views.zero_sensitivity.value
          )
        end
      },
    },
    
    vb:column {
      style = "group",
      width=300,
      --margin = DEFAULT_DIALOG_MARGIN,
      
      vb:text { text = "BPM-Based Slice Movement",style="strong",font="bold", },
      
      vb:row {
        vb:text { text = "Current BPM: " .. (function() local ok, s = pcall(function() return renoise.song() end) return ok and s.transport.bpm or "N/A" end)() },
      },
      
      vb:row {
        vb:button {width=75, text = "Start -1/4", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.25, -1) end},
        vb:button {width=75, text = "Start +1/4", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.25, 1) end },
        vb:button {width=75, text = "End -1/4", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.25, -1) end },
        vb:button {width=75, text = "End +1/4", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.25, 1) end },
      },
      
      vb:row {
        vb:button {width=75, text = "Start -1/8", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.125, -1) end },
        vb:button {width=75, text = "Start +1/8", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.125, 1) end },
        vb:button {width=75, text = "End -1/8", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.125, -1) end },
        vb:button {width=75, text = "End +1/8", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.125, 1) end },
      },
      
      vb:row {
        vb:button {width=75, text = "Start -1/16", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.0625, -1) end },
        vb:button {width=75, text = "Start +1/16", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.0625, 1) end },
        vb:button {width=75, text = "End -1/16", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, -1) end },
        vb:button {width=75, text = "End +1/16", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, 1) end },
      },
      
      vb:row {
        vb:button {width=75, text = "Start -1/32", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.03125, -1) end },
        vb:button {width=75, text = "Start +1/32", notifier = function() PakettiZeroCrossingsMoveSliceStart(0.03125, 1) end },
        vb:button {width=75, text = "End -1/32", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, -1) end },
        vb:button {width=75, text = "End +1/32", notifier = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, 1) end },
      },
    },
  }

  PakettiZeroCrossingsDialog = renoise.app():show_custom_dialog(
    "Paketti Zero Crossings Advanced", 
    dialog_content,
    my_keyhandler_func
  )
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Wrapper functions for quick access
function PakettiZeroCrossingsWipeSlice002() PakettiZeroCrossingsWipeSlice(2, true, 1.0) end
function PakettiZeroCrossingsWipeSlice004() PakettiZeroCrossingsWipeSlice(4, true, 1.0) end
function PakettiZeroCrossingsWipeSlice008() PakettiZeroCrossingsWipeSlice(8, true, 1.0) end
function PakettiZeroCrossingsWipeSlice016() PakettiZeroCrossingsWipeSlice(16, true, 1.0) end
function PakettiZeroCrossingsWipeSlice032() PakettiZeroCrossingsWipeSlice(32, true, 1.0) end
function PakettiZeroCrossingsWipeSlice064() PakettiZeroCrossingsWipeSlice(64, true, 1.0) end
function PakettiZeroCrossingsWipeSlice128() PakettiZeroCrossingsWipeSlice(128, true, 1.0) end

-- Quick randomization functions
function PakettiZeroCrossingsQuickRandomizeSlices() PakettiZeroCrossingsRandomizeSlices(15, true, 1.0) end
function PakettiZeroCrossingsQuickRandomSlices() PakettiZeroCrossingsRandomDistributedSlices(8, 32, true, 1.0) end

--------------------------------------------------------------------------------
-- Preferences
--------------------------------------------------------------------------------

if not preferences.ZeroCrossings then
  preferences.ZeroCrossings = {
    AutoSnapSelection = {value = false}
  }
end

-- Note: PakettiZeroCrossingsInitAutoSnap() will be called when song is available
-- Never call it at module load time to avoid accessing renoise.song() before it's available

--------------------------------------------------------------------------------
-- Key bindings
--------------------------------------------------------------------------------

renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossings Advanced Dialog", invoke = PakettiZeroCrossingsAdvancedDialog}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Snap Selection to Zero Crossings", invoke = function() PakettiZeroCrossingsSnapSelection(1.0) end}

-- Zero crossing wipe & slice keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (002)", invoke = PakettiZeroCrossingsWipeSlice002}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (004)", invoke = PakettiZeroCrossingsWipeSlice004}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (008)", invoke = PakettiZeroCrossingsWipeSlice008}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (016)", invoke = PakettiZeroCrossingsWipeSlice016}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (032)", invoke = PakettiZeroCrossingsWipeSlice032}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (064)", invoke = PakettiZeroCrossingsWipeSlice064}
renoise.tool():add_keybinding{name="Global:Paketti:Zero Crossing Wipe&Slice (128)", invoke = PakettiZeroCrossingsWipeSlice128}

-- Randomization keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Randomize Slice Positions", invoke = PakettiZeroCrossingsQuickRandomizeSlices}
renoise.tool():add_keybinding{name="Global:Paketti:Create Random Distributed Slices", invoke = PakettiZeroCrossingsQuickRandomSlices}

-- BPM-based movement keybindings
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start -1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.25, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start +1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.25, 1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End -1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.25, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End +1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.25, 1) end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start -1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.125, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start +1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.125, 1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End -1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.125, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End +1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.125, 1) end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start -1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.0625, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start +1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.0625, 1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End -1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End +1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, 1) end}

renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start -1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.03125, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice Start +1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.03125, 1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End -1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, -1) end}
renoise.tool():add_keybinding{name="Sample Editor:Paketti:Move Slice End +1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, 1) end}

--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

-- Sample Editor menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:Advanced Dialog", invoke = PakettiZeroCrossingsAdvancedDialog}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:Snap Selection to Zero Crossings", invoke = function() PakettiZeroCrossingsSnapSelection(1.0) end}

-- Zero crossing wipe & slice menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (002)", invoke = PakettiZeroCrossingsWipeSlice002}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (004)", invoke = PakettiZeroCrossingsWipeSlice004}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (008)", invoke = PakettiZeroCrossingsWipeSlice008}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (016)", invoke = PakettiZeroCrossingsWipeSlice016}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (032)", invoke = PakettiZeroCrossingsWipeSlice032}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (064)", invoke = PakettiZeroCrossingsWipeSlice064}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Wipe&Slice:Zero Cross Wipe&Slice (128)", invoke = PakettiZeroCrossingsWipeSlice128}

-- Randomization menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:Randomize:Randomize Existing Slices", invoke = PakettiZeroCrossingsQuickRandomizeSlices}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:Randomize:Create Random Distributed Slices", invoke = PakettiZeroCrossingsQuickRandomSlices}

-- BPM movement menu entries
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start -1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.25, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start +1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.25, 1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End -1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.25, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End +1/4 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.25, 1) end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start -1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.125, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start +1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.125, 1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End -1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.125, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End +1/8 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.125, 1) end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start -1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.0625, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start +1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.0625, 1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End -1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End +1/16 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.0625, 1) end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start -1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.03125, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice Start +1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceStart(0.03125, 1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End -1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, -1) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Zero Crossings:BPM Movement:Move Slice End +1/32 Beat", invoke = function() PakettiZeroCrossingsMoveSliceEnd(0.03125, 1) end}

-- Instrument Box menu entries (for convenience)
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Zero Crossings:Advanced Dialog", invoke = PakettiZeroCrossingsAdvancedDialog}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Zero Crossings:Zero Cross Wipe&Slice (016)", invoke = PakettiZeroCrossingsWipeSlice016}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Zero Crossings:Randomize Slices", invoke = PakettiZeroCrossingsQuickRandomizeSlices}

-- Sample Navigator menu entries (for convenience)  
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Zero Crossings:Advanced Dialog", invoke = PakettiZeroCrossingsAdvancedDialog}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Zero Crossings:Zero Cross Wipe&Slice (016)", invoke = PakettiZeroCrossingsWipeSlice016}

--------------------------------------------------------------------------------
-- MIDI mappings
--------------------------------------------------------------------------------

renoise.tool():add_midi_mapping{name="Paketti:Zero Crossings Advanced Dialog", invoke = function(message) if message:is_trigger() then PakettiZeroCrossingsAdvancedDialog() end end}
renoise.tool():add_midi_mapping{name="Paketti:Snap Selection to Zero Crossings", invoke = function(message) if message:is_trigger() then PakettiZeroCrossingsSnapSelection(1.0) end end}
renoise.tool():add_midi_mapping{name="Paketti:Zero Cross Wipe&Slice (016)", invoke = function(message) if message:is_trigger() then PakettiZeroCrossingsWipeSlice016() end end}
renoise.tool():add_midi_mapping{name="Paketti:Randomize Slice Positions", invoke = function(message) if message:is_trigger() then PakettiZeroCrossingsQuickRandomizeSlices() end end}
renoise.tool():add_midi_mapping{name="Paketti:Create Random Distributed Slices", invoke = function(message) if message:is_trigger() then PakettiZeroCrossingsQuickRandomSlices() end end}
