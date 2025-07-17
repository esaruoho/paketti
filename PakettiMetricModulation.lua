-- PakettiMetricModulation.lua
-- Metric Modulation tools for Renoise
-- Allows transformation of musical content between different metric relationships
-- while preserving audio timing through tempo adjustments

local vb = renoise.ViewBuilder()
local dialog = nil
local subdivision_dialog = nil

local metricWidth = 90
-- Metric modulation state
local mm_state = {
  current_bpm = 120,
  current_lpb = 4,
  target_lpb = 6,
  ratio_numerator = 4,
  ratio_denominator = 3,
  selection_start_line = 1,
  selection_end_line = 16,
  auto_apply = false,
  show_subdivisions = false
}

-- Common metric ratios for quick selection
local common_ratios = {
  {ratio = "4:3", desc = "4/4 to 3/4 feel", num = 4, den = 3},
  {ratio = "3:2", desc = "Triplet feel", num = 3, den = 2},
  {ratio = "2:3", desc = "Reverse triplet", num = 2, den = 3},
  {ratio = "5:4", desc = "Complex polyrhythm", num = 5, den = 4},
  {ratio = "4:5", desc = "Reverse complex", num = 4, den = 5},
  {ratio = "6:4", desc = "3/4 to 4/4 feel", num = 6, den = 4},
  {ratio = "8:6", desc = "4/4 to 6/8 feel", num = 8, den = 6},
  {ratio = "6:8", desc = "6/8 to 4/4 feel", num = 6, den = 8},
  {ratio = "7:4", desc = "Odd time signature", num = 7, den = 4},
  {ratio = "4:7", desc = "Reverse odd time", num = 4, den = 7}
}

-- Advanced subdivision system (based on HTML/JS metric modulation calculator)
local subdivision_values = {
  {id = "quarter_note_subdivision", name = "Quarter Note", symbol = "♩", notes_per_beat = 1},
  {id = "dotted_eighth_subdivision", name = "Dotted Eighth", symbol = "♪.", notes_per_beat = 1 + (1/3)}, -- 1.333...
  {id = "quarter_note_5_3_subdivision", name = "Quarter Note 5:3", symbol = "♩⁵", notes_per_beat = 1 + (2/3)}, -- 1.666...
  {id = "eighth_note_subdivision", name = "Eighth Note", symbol = "♪", notes_per_beat = 2},
  {id = "eighth_note_7_6_subdivision", name = "Eighth Note 7:6", symbol = "♪⁷", notes_per_beat = 2 + (1/3)}, -- 2.333...
  {id = "eighth_note_4_3_subdivision", name = "Eighth Note 4:3", symbol = "♪⁴", notes_per_beat = 2 + (2/3)}, -- 2.666...
  {id = "eighth_triplet_subdivision", name = "Eighth Triplet", symbol = "♪³", notes_per_beat = 3},
  {id = "eighth_note_5_3_subdivision", name = "Eighth Note 5:3", symbol = "♪⁵", notes_per_beat = 3 + (1/3)}, -- 3.333...
  {id = "sixteenth_note_subdivision", name = "Sixteenth Note", symbol = "♬", notes_per_beat = 4},
  {id = "sixteenth_7_6_subdivision", name = "Sixteenth 7:6", symbol = "♬⁷", notes_per_beat = 4 + (2/3)}, -- 4.666...
  {id = "sixteenth_quintuplet_subdivision", name = "Sixteenth Quintuplet", symbol = "♬⁵", notes_per_beat = 5},
  {id = "sixteenth_4_3_subdivision", name = "Sixteenth 4:3", symbol = "♬⁴", notes_per_beat = 5 + (1/3)}, -- 5.333...
  {id = "sixteenth_sextuplet_subdivision", name = "Sixteenth Sextuplet", symbol = "♬⁶", notes_per_beat = 6}
}

-- Calculate new tempo based on metric modulation
function calculate_metric_modulation(original_bpm, ratio_num, ratio_den)
  local new_bpm = original_bpm * (ratio_num / ratio_den)
  return math.floor(new_bpm * 100 + 0.5) / 100 -- Round to 2 decimal places
end

-- Calculate tempo for LPB-based modulation
function calculate_lpb_modulation(original_bpm, original_lpb, target_lpb)
  local new_bpm = original_bpm * (original_lpb / target_lpb)
  return math.floor(new_bpm * 100 + 0.5) / 100
end

-- Calculate BPM for subdivision based on notes per minute
function calculate_subdivision_bpm(notes_per_minute, notes_per_beat)
  return notes_per_minute / notes_per_beat
end

-- Update all subdivision displays when one changes
function update_all_subdivisions(changed_subdivision_bpm, changed_notes_per_beat)
  if not dialog or not mm_state.show_subdivisions then return end
  
  print("-- Metric Modulation: Updating all subdivisions from changed BPM:", format_bpm(changed_subdivision_bpm), "notes_per_beat:", changed_notes_per_beat)
  
  -- Calculate notes per minute from the changed subdivision
  local notes_per_minute = changed_subdivision_bpm * changed_notes_per_beat
  print("-- Metric Modulation: Notes per minute:", notes_per_minute)
  
  -- Update all subdivision displays
  for i, subdivision in ipairs(subdivision_values) do
    local subdivision_bpm = calculate_subdivision_bpm(notes_per_minute, subdivision.notes_per_beat)
    if vb.views[subdivision.id .. "_display"] then
      vb.views[subdivision.id .. "_display"].text = string.format("%sBPM", format_bpm(subdivision_bpm))
      print("-- Metric Modulation: Updated subdivision", subdivision.id, "to", format_bpm(subdivision_bpm), "BPM")
    end
  end
end

-- Analyze current pattern selection for rhythmic content
function analyze_pattern_selection()
  local song = renoise.song()
  local pattern = song:pattern(song.selected_pattern_index)
  local track = pattern:track(song.selected_track_index)
  
  local selection = song.selection_in_pattern
  local start_line, end_line
  
  if selection then
    start_line = selection.start_line
    end_line = selection.end_line
  else
    start_line = song.selected_line_index
    end_line = math.min(start_line + 15, pattern.number_of_lines)
  end
  
  local note_count = 0
  local occupied_lines = {}
  
  -- Count notes and analyze rhythm
  for line_idx = start_line, end_line do
    local line = track:line(line_idx)
    local has_note = false
    
    for _, note_col in ipairs(line.note_columns) do
      if not note_col.is_empty then
        note_count = note_count + 1
        has_note = true
      end
    end
    
    if has_note then
      table.insert(occupied_lines, line_idx - start_line + 1)
    end
  end
  
  return {
    start_line = start_line,
    end_line = end_line,
    length = end_line - start_line + 1,
    note_count = note_count,
    occupied_lines = occupied_lines,
    density = note_count / (end_line - start_line + 1)
  }
end

-- Get master track index
function get_master_track_index()
  for k,v in ripairs(renoise.song().tracks)
    do if v.type == renoise.Track.TRACK_TYPE_MASTER then return k end  
  end
end

-- Write BPM and LPB to master track using effect columns
function PakettiMetricModulationWriteBPMToMaster(bpm_value, lpb_value)
  lpb_value = lpb_value or renoise.song().transport.lpb -- default to current LPB
  if bpm_value and bpm_value < 256 then -- safety check
    local song = renoise.song()
    local master_index = get_master_track_index()
    
    song.tracks[master_index].visible_effect_columns = 2  
    song.selected_pattern.tracks[master_index].lines[1].effect_columns[1].number_string = "ZT"
    song.selected_pattern.tracks[master_index].lines[1].effect_columns[1].amount_value = bpm_value
    song.selected_pattern.tracks[master_index].lines[1].effect_columns[2].number_string = "ZL"
    song.selected_pattern.tracks[master_index].lines[1].effect_columns[2].amount_value = lpb_value
  end
end

-- Validate BPM limits
function validate_bpm(bpm_value)
  if bpm_value > 999 then
    renoise.app():show_warning("BPM cannot exceed 999. Setting to 999.")
    return 999
  elseif bpm_value > 256 then
    renoise.app():show_warning(string.format("BPM %s exceeds ZTFF limit (256). Consider using lower values.", format_bpm(bpm_value)))
    return bpm_value
  end
  return bpm_value
end

-- Apply metric modulation to current selection
function apply_metric_modulation(new_bpm, create_new_pattern, target_lpb)
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  
  -- If target_lpb not specified, keep current LPB (ratio modulation)
  target_lpb = target_lpb or current_lpb
  
  -- Validate BPM limits
  new_bpm = validate_bpm(new_bpm)
  
  if create_new_pattern then
    -- FIRST: Write current BPM/LPB to current pattern (preserve original)
    PakettiMetricModulationWriteBPMToMaster(current_bpm, current_lpb)
    
    -- THEN: Clone current pattern (using same method as clonePTN)
    local n_patterns = #song.patterns
    local src_pat_i = song.selected_pattern_index
    local src_pat = song:pattern(src_pat_i)
    local currline = song.selected_line_index
    
    -- Create new pattern and copy content
    song.selected_pattern_index = n_patterns + 1
    song.patterns[song.selected_pattern_index].number_of_lines = song.patterns[src_pat_i].number_of_lines
    song.selected_pattern:copy_from(src_pat)
    song.selected_line_index = currline
    
    -- NOW: Write NEW BPM/LPB to NEW pattern
    PakettiMetricModulationWriteBPMToMaster(new_bpm, target_lpb)
  end
  
  -- Set transport BPM and LPB
  song.transport.bpm = new_bpm
  song.transport.lpb = target_lpb
  
  if target_lpb ~= current_lpb then
    renoise.app():show_status(string.format("Applied LPB modulation: %s BPM/%d LPB → %s BPM/%d LPB", format_bpm(current_bpm), current_lpb, format_bpm(new_bpm), target_lpb))
  else
    renoise.app():show_status(string.format("Applied metric modulation: %s BPM → %s BPM", format_bpm(current_bpm), format_bpm(new_bpm)))
  end
  
  return new_bpm
end

-- Generate metric modulation suggestions based on current context
function generate_suggestions()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  local analysis = analyze_pattern_selection()
  
  local suggestions = {}
  
  -- LPB-based suggestions
  for target_lpb = 1, 16 do
    if target_lpb ~= current_lpb then
      local new_bpm = calculate_lpb_modulation(current_bpm, current_lpb, target_lpb)
      if new_bpm >= 20 and new_bpm <= 999 then
        table.insert(suggestions, {
          type = "LPB",
          description = string.format("%d LPB → %d LPB", current_lpb, target_lpb),
          current_bpm = current_bpm,
          new_bpm = new_bpm,
          ratio = string.format("%d:%d", current_lpb, target_lpb)
        })
      end
    end
  end
  
  -- Common ratio suggestions
  for _, ratio in ipairs(common_ratios) do
    local new_bpm = calculate_metric_modulation(current_bpm, ratio.num, ratio.den)
    if new_bpm >= 20 and new_bpm <= 999 then
      table.insert(suggestions, {
        type = "Ratio",
        description = ratio.name,
        current_bpm = current_bpm,
        new_bpm = new_bpm,
        ratio = string.format("%d:%d", ratio.num, ratio.den)
      })
    end
  end
  
  return suggestions
end

-- Note value definitions (notes per beat - how many fit in a quarter note)
local note_values = {
  {name = "dotted_half_note", label = "Dotted Half Note", ratio = 3},
  {name = "half_note", label = "Half Note", ratio = 2}, 
  {name = "dotted_quarter_note", label = "Dotted Quarter Note", ratio = 1.5},
  {name = "quarter_note", label = "Quarter Note", ratio = 1},
  {name = "dotted_eighth_note", label = "Dotted Eighth Note", ratio = 0.75},
  {name = "eighth_note", label = "Eighth Note", ratio = 0.5}
}

-- Update all note value fields when one changes
function update_note_values(changed_note_name, new_bpm)
  -- Find the ratio for the changed note
  local changed_ratio = nil
  for _, note in ipairs(note_values) do
    if note.name == changed_note_name then
      changed_ratio = note.ratio
      break
    end
  end
  
  if not changed_ratio then return end
  
  -- Calculate notes per minute from the changed field
  local notes_per_minute = new_bpm * changed_ratio
  
  -- Update all other fields
  for _, note in ipairs(note_values) do
    if note.name ~= changed_note_name then
      local new_note_bpm = notes_per_minute / note.ratio
      -- Round to integer (no decimals)
      new_note_bpm = math.floor(new_note_bpm + 0.5)
      if vb.views[note.name] then
        vb.views[note.name].value = new_note_bpm
      end
    end
  end
end

-- Smart BPM formatting - only show decimals if there's meaningful fractional data
function format_bpm(bpm_value)
  local rounded = math.floor(bpm_value * 100 + 0.5) / 100 -- Round to 2 decimals
  if rounded == math.floor(rounded) then
    return string.format("%d", rounded) -- No decimals if it's a whole number
  else
    return string.format("%.2f", rounded):gsub("%.?0+$", "") -- Remove trailing zeros
  end
end

-- Update calculation display in dialog
function update_calculation_display()
  if dialog then
    if vb.views.ratio_display then
      vb.views.ratio_display.text = string.format("%d:%d", mm_state.ratio_numerator, mm_state.ratio_denominator)
    end
    if vb.views.ratio_result then
      local new_bpm = calculate_metric_modulation(mm_state.current_bpm, mm_state.ratio_numerator, mm_state.ratio_denominator)
      vb.views.ratio_result.text = string.format("(%sBPM→%sBPM)", 
        format_bpm(mm_state.current_bpm), format_bpm(new_bpm))
    end
  end
end

function update_lpb_calculation_display()
  if dialog then
    if vb.views.lpb_display then
      vb.views.lpb_display.text = string.format("%d", mm_state.target_lpb)
    end
    if vb.views.lpb_result then
      local new_bpm = calculate_lpb_modulation(mm_state.current_bpm, mm_state.current_lpb, mm_state.target_lpb)
      vb.views.lpb_result.text = string.format("(%sBPM → %sBPM)", 
        format_bpm(mm_state.current_bpm), format_bpm(new_bpm))
    end
  end
end

-- Refresh dialog with current song data
function refresh_dialog_data()
  local song = renoise.song()
  mm_state.current_bpm = song.transport.bpm
  mm_state.current_lpb = song.transport.lpb
  
  -- Update pattern analysis display
  if dialog and vb.views.pattern_info then
    vb.views.pattern_info.text = string.format("Current Pattern: %s BPM, %d LPB", format_bpm(mm_state.current_bpm), mm_state.current_lpb)
  end
  
  -- Update note value displays
  if dialog then
    if vb.views.eighth_note_display then
      vb.views.eighth_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm * 2))
    end
    if vb.views.dotted_eighth_note_display then
      vb.views.dotted_eighth_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm / 0.75))
    end
    if vb.views.quarter_note_display then
      vb.views.quarter_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm))
    end
    if vb.views.dotted_quarter_note_display then
      vb.views.dotted_quarter_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm / 1.5))
    end
    if vb.views.half_note_display then
      vb.views.half_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm / 2))
    end
    if vb.views.dotted_half_note_display then
      vb.views.dotted_half_note_display.text = string.format("%s BPM", format_bpm(mm_state.current_bpm / 3))
    end
  end
  
  -- Update subdivision displays if visible
  if mm_state.show_subdivisions then
    print("-- Metric Modulation: Refreshing subdivision displays, current BPM:", format_bpm(mm_state.current_bpm))
    for i, subdivision in ipairs(subdivision_values) do
      local subdivision_bpm = calculate_subdivision_bpm(mm_state.current_bpm * subdivision.notes_per_beat, subdivision.notes_per_beat)
      if vb.views[subdivision.id .. "_display"] then
        vb.views[subdivision.id .. "_display"].text = string.format("%sBPM", format_bpm(subdivision_bpm))
        print("-- Metric Modulation: Refreshed subdivision", subdivision.id, "to", format_bpm(subdivision_bpm), "BPM (notes_per_beat:", subdivision.notes_per_beat, ")")
      end
    end
  else
    print("-- Metric Modulation: Subdivision displays not visible, skipping subdivision refresh")
  end
  
  -- Update calculation displays
  update_calculation_display()
  update_lpb_calculation_display()
end

-- Create metric modulation calculator dialog
function show_metric_modulation_dialog()
  -- Close existing dialog first to avoid ViewBuilder ID conflicts
  if dialog and dialog.visible then
    dialog:close()
  end
  
  -- Create fresh ViewBuilder instance to avoid ID conflicts
  local vb = renoise.ViewBuilder()
  
  local song = renoise.song()
  mm_state.current_bpm = song.transport.bpm
  mm_state.current_lpb = song.transport.lpb
  
  local analysis = analyze_pattern_selection()
  local suggestions = generate_suggestions()
  
  -- Prepare switch items (just ratios)
  local switch_items = {}
  for i, ratio in ipairs(common_ratios) do
    table.insert(switch_items, ratio.ratio)
  end

  -- Note: ratio values are now controlled by the quick ratios switch
  -- Note: LPB value is now controlled by the +/- buttons

  local dialog_content = vb:column {
    margin = 10,
    
    -- Analysis section
    vb:text { 
      id = "pattern_info",
      text = string.format("Current Pattern: %sBPM, %dLPB", format_bpm(mm_state.current_bpm), mm_state.current_lpb),
      style = "strong",
      font = "bold"},
        
    -- Metric modulation section (single row) - Column alignment: 140 + 80 + 60 + 200
    vb:row {
      vb:text { text = "Metric Modulation", font="bold", style = "strong", width = 140 },
      vb:text { text = "Ratio:", width = 80 },
      vb:text { 
        id = "ratio_display",
        text = string.format("%d:%d", mm_state.ratio_numerator, mm_state.ratio_denominator),
        width = 60},
      vb:text { 
        id = "ratio_result",
        text = string.format("(%sBPM→%sBPM)", 
          format_bpm(mm_state.current_bpm), 
          format_bpm(calculate_metric_modulation(mm_state.current_bpm, mm_state.ratio_numerator, mm_state.ratio_denominator))),
        width = 200}},

    -- LPB modulation section (single row) - Column alignment: 140 + 80 + 60 + 200
    vb:row {
      vb:text { text = "LPB Modulation", font="bold", style = "strong", width = 140 },
      vb:text { text = "Target LPB:", width = 80 },
      vb:text {
        id = "lpb_display",
        text = string.format("%d", mm_state.target_lpb),
        width = 60
      },
      vb:text {
        id = "lpb_result", 
        text = string.format("(%sBPM→%sBPM)", 
          format_bpm(mm_state.current_bpm), 
          format_bpm(calculate_lpb_modulation(mm_state.current_bpm, mm_state.current_lpb, mm_state.target_lpb))),
        width = 200}},

    -- LPB controls
    vb:row {
      vb:text { text = "", width = 140 }, -- spacer
      vb:text { text = "Adjust:", width = 80 },
      vb:row {
        spacing = 2,
        vb:button {
          text = "-",
          width = 25,
          notifier = function()
            if mm_state.target_lpb > 1 then
              mm_state.target_lpb = mm_state.target_lpb - 1
              update_lpb_calculation_display()
            end
          end
        },
        vb:button {
          text = "+",
          width = 25,
          notifier = function()
            if mm_state.target_lpb < 32 then
              mm_state.target_lpb = mm_state.target_lpb + 1
              update_lpb_calculation_display()
            end
          end}}},
    
    -- Quick presets
    vb:text { text = "Quick Ratios", font="bold",style = "strong" },
    
    vb:switch {
      id = "ratio_switch",
      items = switch_items,
      width = 400,
      value = 1,
      notifier = function(value)
        local ratio = common_ratios[value]
        if ratio then
          mm_state.ratio_numerator = ratio.num
          mm_state.ratio_denominator = ratio.den
          update_calculation_display()
        end
      end
    },
    
    -- Quick ratio descriptions
    vb:text { id = "ratio_descriptions",
      text = "4:3 (4/4 to 3/4 feel)  3:2 (Triplet feel)  2:3 (Reverse triplet)  5:4 (Complex polyrhythm)",width=600},
vb:text {id="ratio_descriptions2",
text="4:5 (Reverse complex)  6:4 (3/4 to 4/4 feel)  8:6 (4/4 to 6/8 feel)  6:8 (6/8 to 4/4 feel)",width=600},
vb:text{id="ratio_descriptions3",
text="  7:4 (Odd time signature)  4:7 (Reverse odd time)",width=600},

    -- Note Value Calculator section
    vb:text { text = "Note Value Calculator", font="bold",style = "strong" },    
    
    -- Eighth Note
    vb:row {
      vb:text { text = "♪", font = "big", style = "strong", width = 25 },
      vb:text { text = "Eighth Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm * 2)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "eighth_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm * 2)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Dotted Eighth Note
    vb:row {
      vb:text { text = "♪.", font = "big", style = "strong", width = 25 },
      vb:text { text = "Dotted Eighth Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm / 0.75)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "dotted_eighth_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm / 0.75)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Quarter Note
    vb:row {
      vb:text { text = "♩", font = "big", style = "strong", width = 25 },
      vb:text { text = "Quarter Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "quarter_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Dotted Quarter Note
    vb:row {
      vb:text { text = "♩.", font = "big", style = "strong", width = 25 },
      vb:text { text = "Dotted Quarter Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm / 1.5)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "dotted_quarter_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm / 1.5)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Half Note
    vb:row {
      vb:text { text = "♫", font = "big", style = "strong", width = 25 },
      vb:text { text = "Half Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm / 2)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "half_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm / 2)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Dotted Half Note
    vb:row {
      vb:text { text = "♫.", font = "big", style = "strong", width = 25 },
      vb:text { text = "Dotted Half Note", style = "strong", font = "bold", width = 140 },
      vb:button {
        text = "Set",
        width = 40,
        notifier = function()
          local bpm_value = validate_bpm(mm_state.current_bpm / 3)
          renoise.song().transport.bpm = bpm_value
          renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
          refresh_dialog_data()
        end},
      vb:text { 
        id = "dotted_half_note_display",
        text = string.format("%sBPM", format_bpm(mm_state.current_bpm / 3)),
        style = "strong",
        font = "bold",
        width = 80}},
    
    -- Options
    vb:row {
      vb:checkbox {id = "create_new_pattern",value = true},
      vb:text { text = "Create new pattern", style = "strong", font = "bold", width=metricWidth }},
    vb:row {
      vb:button {
        text = "Advanced Subdivision Calculator",
        width = metricWidth + 20,
        notifier = function()
          print("-- Metric Modulation: Opening subdivision calculator dialog")
          show_subdivision_calculator_dialog()
        end
      }},
    
    -- Action buttons
    vb:row {
      vb:button {
        text = "Apply Modulation",
        width = 120,
        notifier = function()
          local song = renoise.song()
          local current_lpb = song.transport.lpb
          
          -- Check if user wants LPB modulation (target LPB different from current)
          if mm_state.target_lpb ~= current_lpb then
            -- Apply LPB modulation
            local new_bpm = calculate_lpb_modulation(mm_state.current_bpm, mm_state.current_lpb, mm_state.target_lpb)
            apply_metric_modulation(new_bpm, vb.views.create_new_pattern.value, mm_state.target_lpb)
          else
            -- Apply ratio modulation (keep current LPB)
            local new_bpm = calculate_metric_modulation(mm_state.current_bpm, mm_state.ratio_numerator, mm_state.ratio_denominator)
            apply_metric_modulation(new_bpm, vb.views.create_new_pattern.value)
          end
          refresh_dialog_data()
        end
      },
      vb:button {
        text = "Preview",
        width = 80,
        notifier = preview_metric_modulation}}},
  
    -- Advanced Subdivision Calculator (hidden by default)
    vb:column {
      id = "subdivision_section",
      visible = mm_state.show_subdivisions,
      spacing = 5,
      vb:text { text = "Advanced Subdivision Calculator", font="bold",style = "strong" },
      
      -- Create rows for all subdivisions
      vb:column {
        spacing = 2,
        -- Quarter Note
        vb:row {
          vb:text { text = "♩", font = "big", style = "strong", width = 25 },
          vb:text { text = "Quarter Note", style = "strong", font = "bold", width = 140 },
          vb:button {
            text = "Set",
            width = 40,
            notifier = function()
              local notes_per_beat = 1
              local notes_per_minute = mm_state.current_bpm * notes_per_beat
              local subdivision_bpm = calculate_subdivision_bpm(notes_per_minute, notes_per_beat)
              local bpm_value = validate_bpm(subdivision_bpm)
              renoise.song().transport.bpm = bpm_value
              renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
              refresh_dialog_data()
              update_all_subdivisions(bpm_value, notes_per_beat)
            end},
          vb:text { 
            id = "quarter_note_subdivision_display",
            text = string.format("%sBPM", format_bpm(mm_state.current_bpm)),
            style = "strong",
            font = "bold",
            width = 80}},
        
        -- Dotted Eighth
        vb:row {
          vb:text { text = "♪.", font = "big", style = "strong", width = 25 },
          vb:text { text = "Dotted Eighth", style = "strong", font = "bold", width = 140 },
          vb:button {
            text = "Set",
            width = 40,
            notifier = function()
              local notes_per_beat = 1 + (1/3)
              local notes_per_minute = mm_state.current_bpm * notes_per_beat
              local subdivision_bpm = calculate_subdivision_bpm(notes_per_minute, notes_per_beat)
              local bpm_value = validate_bpm(subdivision_bpm)
              renoise.song().transport.bpm = bpm_value
              renoise.app():show_status(string.format("Song BPM set to %s", format_bpm(bpm_value)))
              refresh_dialog_data()
              update_all_subdivisions(bpm_value, notes_per_beat)
            end},
          vb:text { 
            id = "dotted_eighth_subdivision_display",
            text = string.format("%sBPM", format_bpm(calculate_subdivision_bpm(mm_state.current_bpm * (1 + (1/3)), 1 + (1/3)))),
            style = "strong",
            font = "bold",
            width = 80}}
      }
    }
  
  
  dialog = renoise.app():show_custom_dialog("Paketti Metric Modulation Calculator", dialog_content)
end

-- Preview metric modulation without applying
function preview_metric_modulation()
  local song = renoise.song()
  local ratio_bpm = calculate_metric_modulation(mm_state.current_bpm, mm_state.ratio_numerator, mm_state.ratio_denominator)
  local lpb_bpm = calculate_lpb_modulation(mm_state.current_bpm, mm_state.current_lpb, mm_state.target_lpb)
  
  renoise.app():show_status(string.format("Preview - Ratio: %s BPM | LPB %d: %s BPM", format_bpm(ratio_bpm), mm_state.target_lpb, format_bpm(lpb_bpm)))
end


-- Quick metric modulation functions
function quick_metric_modulation(ratio_num, ratio_den)
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local new_bpm = calculate_metric_modulation(current_bpm, ratio_num, ratio_den)
  
  apply_metric_modulation(new_bpm, true)
  
  renoise.app():show_status(string.format("Quick modulation %d:%d applied: %.1f → %.1f BPM", 
    ratio_num, ratio_den, current_bpm, new_bpm))
end

function quick_lpb_modulation(target_lpb)
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  local current_lpb = song.transport.lpb
  local new_bpm = calculate_lpb_modulation(current_bpm, current_lpb, target_lpb)
  
  apply_metric_modulation(new_bpm, true, target_lpb)
  
  renoise.app():show_status(string.format("LPB modulation applied: %d→%d LPB, %.1f→%.1f BPM", 
    current_lpb, target_lpb, current_bpm, new_bpm))
end

-- Triplet feel converter
function convert_to_triplet_feel()
  quick_metric_modulation(3, 2)
end

function convert_from_triplet_feel()
  quick_metric_modulation(2, 3)
end

-- 4/4 to 3/4 feel converter
function convert_4_to_3_feel()
  quick_metric_modulation(4, 3)
end

function convert_3_to_4_feel()
  quick_metric_modulation(3, 4)
end

-- Menu entries
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Metric Modulation Calculator",
  invoke = function() show_metric_modulation_dialog() end
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Metric Modulation Calculator",
  invoke = function() show_metric_modulation_dialog() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Quick 4:3 (4/4→3/4 feel)",
  invoke = function() convert_4_to_3_feel() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Quick 3:2 (Triplet feel)",
  invoke = function() convert_to_triplet_feel() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Quick 2:3 (From triplet)",
  invoke = function() convert_from_triplet_feel() end
}

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Quick 3:4 (3/4→4/4 feel)",
  invoke = function() convert_3_to_4_feel() end
}

-- Keybindings
renoise.tool():add_keybinding{
  name = "Global:Paketti:Metric Modulation Calculator",
  invoke = function() show_metric_modulation_dialog() end
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Convert to Triplet Feel",
  invoke = function() convert_to_triplet_feel() end
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Convert from Triplet Feel",
  invoke = function() convert_from_triplet_feel() end
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Convert 4to3 Feel",
  invoke = function() convert_4_to_3_feel() end
}

-- MIDI Mappings for real-time metric modulation
renoise.tool():add_midi_mapping{
  name = "Paketti:Metric Modulation 4of3 (4/4→3/4)",
  invoke = function(message) 
    if message:is_trigger() then 
      convert_4_to_3_feel() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Metric Modulation 3of2 (Triplet)",
  invoke = function(message) 
    if message:is_trigger() then 
      convert_to_triplet_feel() 
    end 
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Metric Modulation 2of3 (From Triplet)",
  invoke = function(message) 
    if message:is_trigger() then 
      convert_from_triplet_feel() 
    end 
  end
}

-- Menu entries for subdivision calculator
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Paketti..:Metric Modulation:Advanced Subdivision Calculator",
  invoke = function() show_subdivision_calculator_dialog() end
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti:Advanced Subdivision Calculator",
  invoke = function() show_subdivision_calculator_dialog() end
}

-- Keybinding for subdivision calculator
renoise.tool():add_keybinding{
  name = "Global:Paketti:Advanced Subdivision Calculator",
  invoke = function() show_subdivision_calculator_dialog() end
}

-- Advanced: Real-time metric ratio control via MIDI knob
renoise.tool():add_midi_mapping{
  name = "Paketti:Real-time Metric Ratio x[Knob]",
  invoke = function(message) 
    if message:is_abs_value() then
      -- Map MIDI value (0-127) to common ratios
      local ratios = {
        {3,4}, {4,5}, {5,6}, {4,3}, {3,2}, {5,4}, {6,5}, {2,1}
      }
      local index = math.floor((message.int_value / 127) * (#ratios - 1)) + 1
      local ratio = ratios[index]
      
      if ratio then
        quick_metric_modulation(ratio[1], ratio[2])
      end
    end
  end
}

-- Create separate subdivision calculator dialog
function show_subdivision_calculator_dialog()
  local song = renoise.song()
  local current_bpm = song.transport.bpm
  
  -- Close existing subdivision dialog if open
  if subdivision_dialog and subdivision_dialog.visible then
    subdivision_dialog:close()
    subdivision_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  print("-- Subdivision Calculator: Opening dialog with BPM:", format_bpm(current_bpm))
  
  -- Calculate all subdivision BPMs (matching percuss.io exactly)
  local subdivisions = {
    {name = "♩ Quarter Note", notes_per_beat = 1},
    {name = "♪. Dotted Eighth Note", notes_per_beat = 1 + (1/3)},  -- 1.33333
    {name = "♩ Quarter Note 5:3", notes_per_beat = 1 + (2/3)},    -- 1.66667
    {name = "♪ Eighth Note", notes_per_beat = 2},
    {name = "♪ Eighth Note 7:6", notes_per_beat = 2 + (1/3)},     -- 2.33333
    {name = "♪ Eighth Note 4:3", notes_per_beat = 2 + (2/3)},     -- 2.66667
    {name = "♪ Eighth Note Triplet", notes_per_beat = 3},
    {name = "♪ Eighth Note 5:3", notes_per_beat = 3 + (1/3)},     -- 3.33333
    {name = "♬ Sixteenth Note", notes_per_beat = 4},
    {name = "♬ Sixteenth Note 7:6", notes_per_beat = 4 + (2/3)},  -- 4.66667
    {name = "♬ Sixteenth Note Quintuplet", notes_per_beat = 5},
    {name = "♬ Sixteenth Note 4:3", notes_per_beat = 5 + (1/3)},  -- 5.33333
    {name = "♬ Sixteenth Note Sextuplet", notes_per_beat = 6}
  }
  
  local subdivision_rows = {}
  
  -- Calculate notes per minute from current quarter note BPM
  local notes_per_minute = current_bpm * 1  -- quarter note = 1 notes_per_beat
  print("-- Subdivision Calculator: Notes per minute:", notes_per_minute)
  
  for i, sub in ipairs(subdivisions) do
    -- beatsPerMinute = notesPerMinute / notesPerBeat (percuss.io formula)
    local subdivision_bpm = notes_per_minute / sub.notes_per_beat
    print("-- Subdivision Calculator:", sub.name, "=", format_bpm(subdivision_bpm), "BPM", "(notes_per_beat:", sub.notes_per_beat, ")")
    
          table.insert(subdivision_rows, vb:row {
        vb:text { text = sub.name, width = 220, style = "strong", font = "bold" },
        vb:text { text = string.format("%s BPM", format_bpm(subdivision_bpm)), width = 100, style = "strong" },
        vb:button {
          text = "Set",
          width = 60,
          notifier = function()
            local new_bpm = validate_bpm(subdivision_bpm)
            song.transport.bpm = new_bpm
            renoise.app():show_status(string.format("Song BPM set to %s (%s)", format_bpm(new_bpm), sub.name))
            print("-- Subdivision Calculator: Set BPM to", format_bpm(new_bpm), "for", sub.name)
            
            -- Refresh subdivision dialog if still open
            if subdivision_dialog and subdivision_dialog.visible then
              subdivision_dialog:close()
              show_subdivision_calculator_dialog()
            end
          end
        }
      })
  end
  
  local dialog_content = vb:column {
    margin = 10,
    spacing = 5,
    vb:text { 
      text = string.format("Subdivision Calculator - Current: %s BPM", format_bpm(current_bpm)), 
      font = "bold", 
      style = "strong" 
    },
    vb:text { text = "Click 'Set' to change song BPM to that subdivision value", style = "normal" },
    vb:column { spacing = 3, table.unpack(subdivision_rows) },
    vb:button {
      text = "Close",
      notifier = function()
        if subdivision_dialog and subdivision_dialog.visible then
          subdivision_dialog:close()
          subdivision_dialog = nil
        end
      end
    }
  }
  
  subdivision_dialog = renoise.app():show_custom_dialog("Advanced Subdivision Calculator (13 Subdivisions)", dialog_content)
  print("-- Subdivision Calculator: Dialog opened successfully")
end
