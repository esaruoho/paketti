function DuplicateInstrumentAndSelectNewInstrument_Wrong()
  local original_middle_frame = renoise.app().window.active_middle_frame
  local dialog = nil
  local vb = nil
  local slicer = nil

  local function process_func()
    local rs = renoise.song()
    if rs == nil or rs.selected_instrument == nil then
      renoise.app():show_status("No instrument selected to duplicate.")
      return
    end

    local i = rs.selected_instrument_index
    local original_instrument = rs:instrument(i)
    local external_editor_open = false
    if original_instrument.plugin_properties and original_instrument.plugin_properties.plugin_device then
      if original_instrument.plugin_properties.plugin_device.external_editor_visible then
        external_editor_open = true
        original_instrument.plugin_properties.plugin_device.external_editor_visible = false
      end
    end
    renoise.app():show_status("Duplicating instrument at index " .. tostring(i) .. "...")

    if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
      vb.views.progress_text.text = "Inserting instrument slot..."
    end
    coroutine.yield()
    if slicer and slicer:was_cancelled() then return end

    rs:insert_instrument_at(i + 1)

    if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
      vb.views.progress_text.text = "Analyzing instrument..."
    end
    coroutine.yield()
    if slicer and slicer:was_cancelled() then return end

    local src_inst = rs:instrument(i)
    local dst_inst = rs:instrument(i + 1)

    -- Decide strategy: manual sliced copy for sample-heavy instruments, otherwise fallback to copy_from
    local has_samples = (#src_inst.samples > 0)
    local is_sample_heavy = false
    if has_samples and src_inst.samples[1] and src_inst.samples[1].sample_buffer then
      local sbuf = src_inst.samples[1].sample_buffer
      if sbuf and sbuf.has_sample_data and sbuf.number_of_frames and sbuf.number_of_frames > 0 then
        is_sample_heavy = true
      end
    end

    if not is_sample_heavy and #src_inst.phrases == 0 then
      -- Likely plugin or empty instrument: fast path via copy_from
      if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = "Copying instrument (fast)..."
      end
      coroutine.yield()
      if slicer and slicer:was_cancelled() then return end
      dst_inst:copy_from(src_inst)
    else
      -- Manual, sliced duplication of samples and phrases to avoid timeouts
      if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = "Copying samples..."
      end
      coroutine.yield()
      if slicer and slicer:was_cancelled() then return end

      local function ensure_sample_slot(index)
        if index > #dst_inst.samples then
          dst_inst:insert_sample_at(index)
        end
        return dst_inst:sample(index)
      end

      local function copy_sample_properties(dst_smp, src_smp)
        dst_smp.name = src_smp.name
        dst_smp.transpose = src_smp.transpose
        dst_smp.fine_tune = src_smp.fine_tune
        dst_smp.volume = src_smp.volume
        dst_smp.panning = src_smp.panning
        dst_smp.beat_sync_enabled = src_smp.beat_sync_enabled
        dst_smp.beat_sync_lines = src_smp.beat_sync_lines
        dst_smp.beat_sync_mode = src_smp.beat_sync_mode
        dst_smp.autoseek = src_smp.autoseek
        dst_smp.autofade = src_smp.autofade
        dst_smp.loop_mode = src_smp.loop_mode
        dst_smp.loop_start = src_smp.loop_start
        dst_smp.loop_end = src_smp.loop_end
        dst_smp.loop_release = src_smp.loop_release
        dst_smp.new_note_action = src_smp.new_note_action
        dst_smp.oneshot = src_smp.oneshot
        dst_smp.mute_group = src_smp.mute_group
        dst_smp.interpolation_mode = src_smp.interpolation_mode
        dst_smp.oversample_enabled = src_smp.oversample_enabled
      end

      local function copy_buffer_chunked(dst_buf, src_buf)
        dst_buf:prepare_sample_data_changes()
        local total_frames = src_buf.number_of_frames or 0
        local num_channels = src_buf.number_of_channels or 1
        local chunk_size = 100000
        local pos = 1
        while pos <= total_frames do
          local this_chunk = math.min(chunk_size, total_frames - pos + 1)
          for frame = 0, this_chunk - 1 do
            local fr = pos + frame
            for ch = 1, num_channels do
              dst_buf:set_sample_data(ch, fr, src_buf:sample_data(ch, fr))
            end
          end
          pos = pos + this_chunk
          if dialog and dialog.visible and vb and vb.views and vb.views.progress_text and total_frames > 0 then
            local p = math.floor((pos - 1) / total_frames * 100)
            vb.views.progress_text.text = "Copying sample data... " .. tostring(p) .. "%"
          end
          if slicer and slicer:was_cancelled() then
            dst_buf:finalize_sample_data_changes()
            return false
          end
          coroutine.yield()
        end
        dst_buf:finalize_sample_data_changes()
        return true
      end

      -- Sliced instruments: copy first sample buffer and slice markers, then per-slice properties
      local first = has_samples and src_inst.samples[1] or nil
      local has_slices = first and (#first.slice_markers > 0)
      if has_slices then
        local dst_first = ensure_sample_slot(1)
        local sbuf = first.sample_buffer
        local dbuf = dst_first.sample_buffer
        dbuf:create_sample_data(sbuf.sample_rate, sbuf.bit_depth, sbuf.number_of_channels, sbuf.number_of_frames)
        if not copy_buffer_chunked(dbuf, sbuf) then return end

        -- Clear existing slice markers (if any)
        while #dst_first.slice_markers > 0 do
          local marker_pos = dst_first.slice_markers[1]
          dst_first:delete_slice_marker(marker_pos)
        end
        -- Insert markers from source
        for _, marker in ipairs(first.slice_markers) do
          dst_first:insert_slice_marker(marker)
        end
        copy_sample_properties(dst_first, first)

        -- Copy per-slice properties to alias slots
        for slice_idx = 2, #src_inst.samples do
          local src_slice = src_inst.samples[slice_idx]
          local dst_slice = ensure_sample_slot(slice_idx)
          copy_sample_properties(dst_slice, src_slice)
        end
      else
        -- Non-sliced instrument: copy each sample
        for sidx = 1, #src_inst.samples do
          local src_smp = src_inst.samples[sidx]
          local dst_smp = ensure_sample_slot(sidx)
          local sbuf = src_smp.sample_buffer
          if sbuf and sbuf.has_sample_data and sbuf.number_of_frames and sbuf.number_of_frames > 0 then
            local dbuf = dst_smp.sample_buffer
            dbuf:create_sample_data(sbuf.sample_rate, sbuf.bit_depth, sbuf.number_of_channels, sbuf.number_of_frames)
            if not copy_buffer_chunked(dbuf, sbuf) then return end
          end
          copy_sample_properties(dst_smp, src_smp)
          if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
            vb.views.progress_text.text = string.format("Copied sample %d/%d", sidx, #src_inst.samples)
          end
          coroutine.yield()
          if slicer and slicer:was_cancelled() then return end
        end
      end

      -- Copy phrases (fast, much smaller than sample data)
      if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
        vb.views.progress_text.text = "Copying phrases..."
      end
      for phrase_index = 1, #src_inst.phrases do
        dst_inst:insert_phrase_at(phrase_index)
        dst_inst.phrases[phrase_index]:copy_from(src_inst.phrases[phrase_index])
        if dialog and dialog.visible and vb and vb.views and vb.views.progress_text then
          vb.views.progress_text.text = string.format("Copied phrase %d/%d", phrase_index, #src_inst.phrases)
        end
        coroutine.yield()
        if slicer and slicer:was_cancelled() then return end
      end
    end

    coroutine.yield()
    if slicer and slicer:was_cancelled() then return end

    rs.selected_instrument_index = i + 1

    if original_middle_frame == 3 then
      renoise.app().window.active_middle_frame = 3
    elseif original_middle_frame == 9 then
      renoise.app().window.active_middle_frame = 9
    else
      renoise.app().window.active_middle_frame = original_middle_frame
    end

    renoise.app():show_status("Instrument duplicated and selected (index " .. tostring(i + 1) .. ")")

    if external_editor_open then
      local new_instrument = rs:instrument(i + 1)
      if new_instrument and new_instrument.plugin_properties and new_instrument.plugin_properties.plugin_device then
        new_instrument.plugin_properties.plugin_device.external_editor_visible = true
      end
    end

    if dialog and dialog.visible then
      dialog:close()
    end
  end

  slicer = ProcessSlicer(process_func)
  dialog, vb = slicer:create_dialog("Duplicating Instrument...")
  if vb and vb.views and vb.views.progress_text then
    vb.views.progress_text.text = "Preparing to duplicate instrument..."
  end
  slicer:start()
end

function DuplicateInstrumentAndSelectNewInstrument()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  local rs = renoise.song()
  if rs == nil or rs.selected_instrument == nil then
    renoise.app():show_status("No instrument selected to duplicate.")
    return
  end
  local i = rs.selected_instrument_index
  if renoise.app().window.active_middle_frame == 3 then
    rs:insert_instrument_at(i + 1):copy_from(rs.selected_instrument)
    rs.selected_instrument_index = i + 1
    renoise.app().window.active_middle_frame = 3
  else
    if renoise.app().window.active_middle_frame == 9 then
      rs:insert_instrument_at(i + 1):copy_from(rs.selected_instrument)
      rs.selected_instrument_index = i + 1
      renoise.app().window.active_middle_frame = 9
    else
      rs:insert_instrument_at(i + 1):copy_from(rs.selected_instrument)
      rs.selected_instrument_index = i + 1
    end
  end
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (2nd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (3rd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument() end}

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (Wrong)",invoke=function() DuplicateInstrumentAndSelectNewInstrument_Wrong() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (Wrong)(2nd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument_Wrong() end}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select New Instrument (Wrong)(3rd)",invoke=function() DuplicateInstrumentAndSelectNewInstrument_Wrong() end}

function duplicateSelectInstrumentToLastInstrument()
local rs=renoise.song()
local n_instruments = #rs.instruments
local src_inst_i = rs.selected_instrument_index
local src_inst = rs:instrument(src_inst_i)

rs:insert_instrument_at(n_instruments)
rs.selected_instrument_index = n_instruments

rs.selected_instrument:copy_from(src_inst)
end

renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Instrument and Select Last Instrument",invoke=function() duplicateSelectInstrumentToLastInstrument() end}

-- auto-suspend plugin off:
function autosuspendOFF()
renoise.song().instruments[renoise.song().selected_instrument_index].plugin_properties.auto_suspend=false
end


-------------------------
function selectplay(number)
local s=renoise.song()
local currPatt=renoise.song().selected_pattern_index
local currTrak=renoise.song().selected_track_index
local currColumn=renoise.song().selected_note_column_index
local currLine=renoise.song().selected_line_index
local currSample=nil 
local resultant=nil

    s.selected_instrument_index=number+1

if renoise.song().transport.edit_mode==false then return end

-- Check if a note column is selected
if currColumn==0 then
    renoise.app():show_status("Please Select a Note Column.")
    return
end

    currSample=s.selected_instrument_index-1
    s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[currColumn].note_string="C-4"
    s.patterns[currPatt].tracks[currTrak].lines[currLine].note_columns[currColumn].instrument_value=currSample

  if renoise.song().transport.follow_player==false 
    then 
resultant=renoise.song().selected_line_index+renoise.song().transport.edit_step
    if renoise.song().selected_pattern.number_of_lines<resultant
    then renoise.song().selected_line_index=renoise.song().selected_pattern.number_of_lines
    else renoise.song().selected_line_index=renoise.song().selected_line_index+renoise.song().transport.edit_step
    end
  else return
  end

end

for i = 0,9 do
renoise.tool():add_keybinding{name="Global:Paketti:Numpad SelectPlay " .. i,invoke=function() selectPlay(i) end}
end

------------------------------------------------------------------------------------------------------
-- Global variable to track stepper cycling state
local stepper_cycle_state = {
  active = false,
  current_instrument = nil,
  current_step = 0
}

-- Stepper cycle order
local stepper_cycle_order = {
  "Cutoff Stepper",
  "Resonance Stepper", 
  "Pitch Stepper",
  "Volume Stepper",
  "Panning Stepper",
  "Drive Stepper"
}

-- Function to reset stepper cycle state
local function reset_stepper_cycle()
  stepper_cycle_state.active = false
  stepper_cycle_state.current_instrument = nil
  stepper_cycle_state.current_step = 0
end

-- Function to hide all steppers
local function hide_all_steppers()
  if PakettiSetStepperVisible then
    for _, stepper_name in ipairs(stepper_cycle_order) do
      PakettiSetStepperVisible(stepper_name, false, true)
    end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Capture Nearest Instrument and Octave (nojump)",invoke=function(repeated) capture_ins_oct("no") end}
renoise.tool():add_keybinding{name="Global:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}
renoise.tool():add_keybinding{name="Mixer:Paketti:Capture Nearest Instrument and Octave (jump)",invoke=function(repeated) capture_ins_oct("yes") end}

function capture_ins_oct(state)
   local closest_note = {}  
   local current_track = renoise.song().selected_track_index
   local current_pattern = renoise.song().selected_pattern_index
   local found_note = false
   
   -- Check if we're in an effect column
   local in_effect_column = (renoise.song().selected_effect_column_index > 0)
   
   -- Find current position in pattern sequence
   local current_sequence_pos = 1
   local sequence = renoise.song().sequencer.pattern_sequence
   for i, pattern_index in ipairs(sequence) do
      if pattern_index == current_pattern then
         current_sequence_pos = i
         break
      end
   end
   
   -- Function to search for notes in a specific pattern
   local function search_pattern_for_notes(pattern_idx, search_for_current_instrument)
      local found_any_note = false
      local found_current_instrument_note = false
      
      for pos, line in renoise.song().pattern_iterator:lines_in_pattern_track(pattern_idx, current_track) do
         if (not line.is_empty) then
            for i = 1, renoise.song().tracks[current_track].visible_note_columns do
               local notecol = line.note_columns[i]
               -- Skip notes without valid instrument values (255 means empty/no instrument)
               if (not notecol.is_empty and notecol.note_string ~= "OFF" and notecol.instrument_value ~= 255) then
                  found_any_note = true
                  
                  -- Check if this is the current instrument
                  if search_for_current_instrument and notecol.instrument_value + 1 == renoise.song().selected_instrument_index then
                     found_current_instrument_note = true
                     break
                  end
                  
                  -- Calculate distance from current edit position
                  local distance = math.abs(pos.line - renoise.song().transport.edit_pos.line)
                  local sequence_distance = math.abs(i - current_sequence_pos)
                  local total_distance = distance + (sequence_distance * 1000) -- Weight sequence distance heavily
                  
                  if (closest_note.oct == nil) then
                     closest_note.oct = math.min(math.floor(notecol.note_value / 12), 8)
                     closest_note.line = pos.line
                     closest_note.ins = notecol.instrument_value + 1
                     closest_note.note = notecol.note_value
                     closest_note.pattern = pattern_idx
                     closest_note.distance = total_distance
                  elseif (total_distance < closest_note.distance) then
                     closest_note.oct = math.min(math.floor(notecol.note_value / 12), 8)
                     closest_note.line = pos.line
                     closest_note.ins = notecol.instrument_value + 1
                     closest_note.note = notecol.note_value
                     closest_note.pattern = pattern_idx
                     closest_note.distance = total_distance
                  end
               end
            end
         end
         if found_current_instrument_note then break end
      end
      
      return found_any_note, found_current_instrument_note
   end
   
   -- First, check current pattern for current instrument notes
   local found_current_instrument_note = false
   for pos, line in renoise.song().pattern_iterator:lines_in_pattern_track(current_pattern, current_track) do
      if (not line.is_empty) then
         for i = 1, renoise.song().tracks[current_track].visible_note_columns do
            local notecol = line.note_columns[i]
            -- Skip notes without valid instrument values (255 means empty/no instrument)
            if (not notecol.is_empty and notecol.note_string ~= "OFF" and 
                notecol.instrument_value ~= 255 and
                notecol.instrument_value + 1 == renoise.song().selected_instrument_index) then
               found_current_instrument_note = true
               break
            end
         end
      end
      if found_current_instrument_note then break end
   end

   -- If we're in Sample Editor and no notes found, try to go to Phrase Editor
   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR and not found_current_instrument_note then
      local instrument = renoise.song().instruments[renoise.song().selected_instrument_index]
      if instrument and #instrument.phrases > 0 then
         renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
         renoise.song().selected_phrase_index = 1
         renoise.app():show_status("No notes found, switching to Phrase Editor.")
         return
      end
   end

   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR and renoise.song().selected_phrase == nil and #renoise.song().selected_instrument.phrases == 0 then 
      pakettiInitPhraseSettingsCreateNewPhrase()
      renoise.song().selected_phrase_index = 1
   return end

   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      renoise.app():show_status("Back to Pattern Editor.")
      return
   end

   -- Search current pattern first
   search_pattern_for_notes(current_pattern, false)
   
   -- If no notes found in current pattern, expand search to nearby patterns in sequence
   if not closest_note.ins then
      local max_search_distance = 10 -- Maximum patterns to search in each direction
      local patterns_searched = 0
      
      for distance = 1, max_search_distance do
         local found_any = false
         
         -- Search patterns before current position
         local prev_pattern_pos = current_sequence_pos - distance
         if prev_pattern_pos >= 1 and prev_pattern_pos <= #sequence then
            local prev_pattern = sequence[prev_pattern_pos]
            local found_prev, _ = search_pattern_for_notes(prev_pattern, false)
            if found_prev then found_any = true end
         end
         
         -- Search patterns after current position
         local next_pattern_pos = current_sequence_pos + distance
         if next_pattern_pos >= 1 and next_pattern_pos <= #sequence then
            local next_pattern = sequence[next_pattern_pos]
            local found_next, _ = search_pattern_for_notes(next_pattern, false)
            if found_next then found_any = true end
         end
         
         -- If we found notes at this distance, stop searching further
         if found_any then break end
      end
   end
   


   if not closest_note.ins then
      renoise.app():show_status("No nearby instrument found.")
      return
   end

   -- Step 1: If the nearest instrument is not selected, select it
   if renoise.song().selected_instrument_index ~= closest_note.ins then
      renoise.song().selected_instrument_index = closest_note.ins
      renoise.song().transport.octave = closest_note.oct
      
      -- If in effect column and using "jump", start stepper cycle immediately
      if in_effect_column and state == "yes" then
         stepper_cycle_state.active = true
         stepper_cycle_state.current_instrument = closest_note.ins
         stepper_cycle_state.current_step = 1  -- Start at first stepper
         
         -- Show the first stepper immediately
         local stepper_name = stepper_cycle_order[1]
         if PakettiSetStepperVisible then
            hide_all_steppers()
            PakettiSetStepperVisible(stepper_name, true, true)
            renoise.app():show_status(string.format("Showing %s (1/%d)", stepper_name, #stepper_cycle_order))
         else
            renoise.app():show_status("Stepper functions not available.")
         end
      else
         renoise.app():show_status("Instrument captured. Run the script again to jump to the sample.")
      end
      return
   end

   -- Handle stepper cycling if in effect column with "jump" state
   if in_effect_column and state == "yes" then
      -- If stepper cycle is active for this instrument, continue cycling
      if stepper_cycle_state.active and stepper_cycle_state.current_instrument == renoise.song().selected_instrument_index then
         stepper_cycle_state.current_step = stepper_cycle_state.current_step + 1
         
         -- If we've cycled through all steppers, go back to pattern editor
         if stepper_cycle_state.current_step > #stepper_cycle_order then
            hide_all_steppers()
            reset_stepper_cycle()
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
            renoise.app():show_status("Back to Pattern Editor.")
            return
         end
         
         -- Show the current stepper in the cycle
         local stepper_name = stepper_cycle_order[stepper_cycle_state.current_step]
         
         if PakettiSetStepperVisible then
            hide_all_steppers()
            PakettiSetStepperVisible(stepper_name, true, true)
            renoise.app():show_status(string.format("Showing %s (%d/%d)", stepper_name, stepper_cycle_state.current_step, #stepper_cycle_order))
         else
            renoise.app():show_status("Stepper functions not available.")
            reset_stepper_cycle()
         end
         return
      else
         -- Instrument already selected but stepper cycle not active, start cycling immediately
         stepper_cycle_state.active = true
         stepper_cycle_state.current_instrument = renoise.song().selected_instrument_index
         stepper_cycle_state.current_step = 1  -- Start at first stepper
         
         -- Show the first stepper immediately
         local stepper_name = stepper_cycle_order[1]
         if PakettiSetStepperVisible then
            hide_all_steppers()
            PakettiSetStepperVisible(stepper_name, true, true)
            renoise.app():show_status(string.format("Showing %s (1/%d)", stepper_name, #stepper_cycle_order))
         else
            renoise.app():show_status("Stepper functions not available.")
         end
         return
      end
   end

   -- Reset stepper cycle if not in effect column or using "no" state
   if not in_effect_column or state == "no" then
      if stepper_cycle_state.active then
         hide_all_steppers()
         reset_stepper_cycle()
      end
   end

   -- Step 2: If in the Sample Editor, toggle back to the Pattern Editor
   if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      renoise.app():show_status("Back to Pattern Editor.")
      return
   end

   -- Step 3: If instrument is selected, jump to the nearest sample/phrase in the editor
   if state == "yes" then
      local instrument = renoise.song().instruments[closest_note.ins]
      
      -- Check if instrument has phrases
      if instrument and #instrument.phrases > 0 then
         -- If we're in phrase editor, go back to pattern editor
         if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR then
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
            renoise.app():show_status("Back to Pattern Editor.")
            return
         end
         
         -- Go to phrase editor
         renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR
         renoise.song().selected_phrase_index = 1
         renoise.app():show_status("Instrument captured, jumping to Phrase Editor.")
         return
      end
      
      -- If no phrases, fall back to original sample editor behavior
      if instrument and #instrument.samples > 0 then
         -- Find sample by note mapping
         local sample_index = 1
         for i, sample_map in ipairs(instrument.sample_mappings[1]) do
            if closest_note.note >= sample_map.note_range[1] and closest_note.note <= sample_map.note_range[2] then
               sample_index = i
               break
            end
         end
         renoise.song().selected_sample_index = sample_index

         renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
         renoise.app():show_status("Instrument and sample captured, jumping to Sample Editor.")
         return
      else
         renoise.app():show_status("No samples available in the instrument.")
         return
      end
   end
end


--------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper function to ensure the required number of instruments exist, with a max limit of 255 (FE)
local function ensure_instruments_count(count)
  local song=renoise.song()
  local max_instruments = 255  -- Allow creation up to 255 instruments (FE in hex)

  while #song.instruments < count and #song.instruments <= max_instruments do
    song:insert_instrument_at(#song.instruments + 1)
  end
end

-- Function to select the next chunk, properly handling the maximum chunk of FE
function select_next_chunk()
  local song=renoise.song()
  local current_index = song.selected_instrument_index
  local next_chunk_index = math.floor((current_index - 1) / 16) * 16 + 16 + 1  -- Calculate the next chunk, ensuring alignment

  -- Ensure the next chunk index does not exceed the maximum of 256 (index 255)
  next_chunk_index = math.min(next_chunk_index, 255)

  ensure_instruments_count(next_chunk_index)
  song.selected_instrument_index = next_chunk_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to select the previous chunk, properly handling lower bounds and correct chunk stepping
function select_previous_chunk()
  local song=renoise.song()
  local current_index = song.selected_instrument_index

  -- Correctly calculate the previous chunk, ensuring it does not get stuck or fail to decrement
  local previous_chunk_index = math.max(1, math.floor((current_index - 2) / 16) * 16 + 1)

  song.selected_instrument_index = previous_chunk_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to directly select a specific chunk, limited to FE as the maximum chunk
local function select_chunk(chunk_index)
  local target_index = chunk_index + 1
  ensure_instruments_count(target_index)
  renoise.song().selected_instrument_index = target_index
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Global:Paketti:Select Next Chunk (00..F0)",invoke=select_next_chunk }
renoise.tool():add_keybinding{name="Global:Paketti:Select Previous Chunk (00..F0)",invoke=select_previous_chunk }

renoise.tool():add_midi_mapping{name="Paketti:Select Next Chunk (00..FE)",
  invoke=function(message) if message:is_trigger() then select_next_chunk() end end
}

renoise.tool():add_midi_mapping{name="Paketti:Select Previous Chunk (00..FE)",
  invoke=function(message) if message:is_trigger() then select_previous_chunk() end end
}

for i = 0, 15 do
  local chunk_hex = string.format("%02X", i * 16)
  local chunk_index = i * 16

  renoise.tool():add_keybinding{name="Global:Paketti:Select Chunk " .. chunk_hex,
    invoke=function() select_chunk(chunk_index) end}

  renoise.tool():add_midi_mapping{name="Paketti:Select Chunk " .. chunk_hex,
    invoke=function(message) if message:is_trigger() then select_chunk(chunk_index) end end}
end

function PakettiInsertNewInstrument()
  local rs = renoise.song()
  local current_index = rs.selected_instrument_index
  local new_index = current_index + 1
  
  rs:insert_instrument_at(new_index)
  rs.selected_instrument_index = new_index
  
  renoise.app():show_status("New instrument inserted at index " .. tostring(new_index))
end

function PakettiDeleteCurrentInstrument()
  local rs = renoise.song()
  local current_index = rs.selected_instrument_index
  
  -- Check if there's more than one instrument to prevent deleting the last one
  if #rs.instruments <= 1 then
    renoise.app():show_status("Cannot delete the last instrument")
    return
  end
  
  rs:delete_instrument_at(current_index)
  renoise.app():show_status("Instrument at index " .. tostring(current_index) .. " deleted")
end

renoise.tool():add_keybinding{name="Global:Paketti:Insert New Instrument", invoke=function() PakettiInsertNewInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Insert New Instrument (2nd)", invoke=function() PakettiInsertNewInstrument() end}

renoise.tool():add_keybinding{name="Global:Paketti:Delete Current Instrument", invoke=function() PakettiDeleteCurrentInstrument() end}
renoise.tool():add_keybinding{name="Global:Paketti:Delete Current Instrument (2nd)", invoke=function() PakettiDeleteCurrentInstrument() end}

function PakettiLoadPlaidZapXRNI()
  renoise.app():load_instrument("Gifts/plaidzap.xrni")
end

renoise.tool():add_keybinding{name="Global:Paketti:Load Plaid Zap .XRNI", invoke=function() PakettiLoadPlaidZapXRNI() end}

