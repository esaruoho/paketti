function globalToggleVisibleColumnState(columnName)
  -- Get the current state of the specified column from the selected track
  local currentState = false
  local selected_track = renoise.song().selected_track

  if columnName == "delay" then
    currentState = selected_track.delay_column_visible
  elseif columnName == "volume" then
    currentState = selected_track.volume_column_visible
  elseif columnName == "panning" then
    currentState = selected_track.panning_column_visible
  elseif columnName == "sample_effects" then
    currentState = selected_track.sample_effects_column_visible
  else
    renoise.app():show_status("Invalid column name: " .. columnName)
    return
  end

  -- Toggle the state for all tracks of type 1
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 then
      if columnName == "delay" then
        renoise.song().tracks[i].delay_column_visible = not currentState
      elseif columnName == "volume" then
        renoise.song().tracks[i].volume_column_visible = not currentState
      elseif columnName == "panning" then
        renoise.song().tracks[i].panning_column_visible = not currentState
      elseif columnName == "sample_effects" then
        renoise.song().tracks[i].sample_effects_column_visible = not currentState
      end
    end
  end
end

function globalChangeVisibleColumnState(columnName,toggle)
  for i=1, renoise.song().sequencer_track_count do
    if renoise.song().tracks[i].type == 1 and columnName == "delay" then
      renoise.song().tracks[i].delay_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "volume" then
      renoise.song().tracks[i].volume_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "panning" then
      renoise.song().tracks[i].panning_column_visible = toggle
    elseif renoise.song().tracks[i].type == 1 and columnName == "sample_effects" then
      renoise.song().tracks[i].sample_effects_column_visible = toggle
    else
      renoise.app():show_status("Invalid column name: " .. columnName)
    end
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (All)",invoke=function() globalChangeVisibleColumnState("volume",true)
globalChangeVisibleColumnState("panning",true) globalChangeVisibleColumnState("delay",true) globalChangeVisibleColumnState("sample_effects",true) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Visible Column (None)",invoke=function() globalChangeVisibleColumnState("volume",false)
globalChangeVisibleColumnState("panning",false) globalChangeVisibleColumnState("delay",false) globalChangeVisibleColumnState("sample_effects",false) end}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Volume)",invoke=function() globalToggleVisibleColumnState("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Panning)",invoke=function() globalToggleVisibleColumnState("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Delay)",invoke=function() globalToggleVisibleColumnState("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Toggle Visible Column (Sample Effects)",invoke=function() globalToggleVisibleColumnState("sample_effects") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Volume)",invoke=function() globalChangeVisibleColumnState("volume",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Panning)",invoke=function() globalChangeVisibleColumnState("panning",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Delay)",invoke=function() globalChangeVisibleColumnState("delay",true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Global Set Visible Column (Sample Effects)",invoke=function() globalChangeVisibleColumnState("sample_effects",true) end}


---
-- Function to toggle columns with configurable options
function toggleColumns(include_sample_effects)
  local song=renoise.song()
  
  -- Check the first track's state to determine if we should show or hide
  local first_track = song.tracks[1]
  local should_show = not (
      first_track.volume_column_visible and
      first_track.panning_column_visible and
      first_track.delay_column_visible and
      (not include_sample_effects or first_track.sample_effects_column_visible)
  )
  
  -- Iterate through all tracks (except Master and Send tracks)
  for track_index = 1, song.sequencer_track_count do
      local track = song.tracks[track_index]
      -- Set all basic columns
      track.volume_column_visible = should_show
      track.panning_column_visible = should_show
      track.delay_column_visible = should_show
      -- Set sample effects based on parameter
      if include_sample_effects then
          track.sample_effects_column_visible = should_show
      else
          track.sample_effects_column_visible = false
      end
  end
  
  -- Show status message
  local message = should_show and 
      (include_sample_effects and "Showing all columns across all tracks" or 
                                "Showing all columns except sample effects across all tracks") or 
      "Hiding all columns across all tracks"
  renoise.app():show_status(message)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle All Columns",invoke=function() toggleColumns(true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle All Columns (No Sample Effects)",invoke=function() toggleColumns(false) end}


---
-- Function to toggle showing only one specific column type
function showOnlyColumnType(column_type)
  local song=renoise.song()
  
  -- Validate column_type parameter
  if not column_type or type(column_type) ~= "string" then
      print("Invalid column type specified")
      return
  end
  
  -- Map of valid column types to their corresponding track properties
  local column_properties = {
      ["volume"] = "volume_column_visible",
      ["panning"] = "panning_column_visible",
      ["delay"] = "delay_column_visible",
      ["effects"] = "sample_effects_column_visible"
  }
  
  -- Check if the specified column type is valid
  if not column_properties[column_type] then
      print("Invalid column type: " .. column_type)
      return
  end
  
  -- Check if we're already showing only this column type
  local is_showing_only_this = true
  for track_index = 1, song.sequencer_track_count do
      local track = song.tracks[track_index]
      -- Check if current column is visible and others are hidden
      if not track[column_properties[column_type]] or
         (column_type ~= "volume" and track.volume_column_visible) or
         (column_type ~= "panning" and track.panning_column_visible) or
         (column_type ~= "delay" and track.delay_column_visible) or
         (column_type ~= "effects" and track.sample_effects_column_visible) then
          is_showing_only_this = false
          break
      end
  end
  
  -- Iterate through all tracks (except Master and Send tracks)
  for track_index = 1, song.sequencer_track_count do
      local track = song.tracks[track_index]
      
      -- Hide all columns first
      track.volume_column_visible = false
      track.panning_column_visible = false
      track.delay_column_visible = false
      track.sample_effects_column_visible = false
      
      -- If we weren't already showing only this column, show it
      if not is_showing_only_this then
          track[column_properties[column_type]] = true
      end
  end
  
  -- Show status message
  local message = is_showing_only_this and 
      "Hiding all columns" or 
      "Showing only " .. column_type .. " columns across all tracks"
  renoise.app():show_status(message)
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Toggle Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Volume Columns",invoke=function() showOnlyColumnType("volume") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Panning Columns",invoke=function() showOnlyColumnType("panning") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Delay Columns",invoke=function() showOnlyColumnType("delay") end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Show Only Effect Columns",invoke=function() showOnlyColumnType("effects") end}

-------
-- Helper function to analyze and hide unused columns for a single track
local function hideUnusedColumnsForTrack(track, track_index, verbose_debug)
  local song = renoise.song()
  local track_columns_hidden = 0
  
  -- Skip non-sequencer tracks
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return 0
  end
  
  local debug_prefix = verbose_debug and "  " or ""
  if verbose_debug then
    print(string.format("Processing Track %d: %s", track_index, track.name))
  end
  
  -- Initialize usage tracking
  local note_columns_used = {}
  for col = 1, track.max_note_columns do
    note_columns_used[col] = false
  end
  
  local effect_columns_used = {}
  for col = 1, track.max_effect_columns do
    effect_columns_used[col] = false
  end
  
  local delay_column_used = false
  local volume_column_used = false
  local panning_column_used = false
  local sample_effects_column_used = false
  
  -- Scan all patterns for this track
  for pattern_index = 1, #song.patterns do
    local pattern = song.patterns[pattern_index]
    local pattern_track = pattern.tracks[track_index]
    
    -- Scan all lines in this pattern
    for line_index = 1, pattern.number_of_lines do
      local line = pattern_track:line(line_index)
      
      -- Check note columns
      for col = 1, #line.note_columns do
        local note_col = line.note_columns[col]
        if note_col.note_string ~= "---" or 
           note_col.instrument_value ~= 255 or
           note_col.volume_value ~= 255 or
           note_col.panning_value ~= 255 or
           note_col.delay_value ~= 0 or
           note_col.effect_number_value ~= 0 or
           note_col.effect_amount_value ~= 0 then
          note_columns_used[col] = true
        end
        
        -- Check special columns within note columns
        if note_col.delay_value ~= 0 then
          delay_column_used = true
        end
        if note_col.volume_value ~= 255 then
          volume_column_used = true
        end
        if note_col.panning_value ~= 255 then
          panning_column_used = true
        end
        if note_col.effect_number_value ~= 0 or note_col.effect_amount_value ~= 0 then
          sample_effects_column_used = true
        end
      end
      
      -- Check effect columns
      for col = 1, #line.effect_columns do
        local effect_col = line.effect_columns[col]
        if effect_col.number_string ~= "00" or effect_col.amount_value ~= 0 then
          effect_columns_used[col] = true
        end
      end
    end
  end
  
  -- Hide unused note columns (count from the end)
  local last_used_note_col = 0
  for col = track.max_note_columns, 1, -1 do
    if note_columns_used[col] then
      last_used_note_col = col
      break
    end
  end
  
  if last_used_note_col < track.visible_note_columns then
    local old_visible = track.visible_note_columns
    track.visible_note_columns = math.max(1, last_used_note_col) -- At least 1 note column
    local hidden = old_visible - track.visible_note_columns
    track_columns_hidden = track_columns_hidden + hidden
    print(string.format("%sNote columns: %d -> %d (hidden %d)", debug_prefix, old_visible, track.visible_note_columns, hidden))
  end
  
  -- Hide unused effect columns (count from the end)
  local last_used_effect_col = 0
  for col = track.max_effect_columns, 1, -1 do
    if effect_columns_used[col] then
      last_used_effect_col = col
      break
    end
  end
  
  if last_used_effect_col < track.visible_effect_columns then
    local old_visible = track.visible_effect_columns
    track.visible_effect_columns = last_used_effect_col
    local hidden = old_visible - track.visible_effect_columns
    track_columns_hidden = track_columns_hidden + hidden
    print(string.format("%sEffect columns: %d -> %d (hidden %d)", debug_prefix, old_visible, track.visible_effect_columns, hidden))
  end
  
  -- Hide unused special columns
  if not delay_column_used and track.delay_column_visible then
    track.delay_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print(debug_prefix .. "Hidden delay column")
  end
  
  if not volume_column_used and track.volume_column_visible then
    track.volume_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print(debug_prefix .. "Hidden volume column")
  end
  
  if not panning_column_used and track.panning_column_visible then
    track.panning_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print(debug_prefix .. "Hidden panning column")
  end
  
  if not sample_effects_column_used and track.sample_effects_column_visible then
    track.sample_effects_column_visible = false
    track_columns_hidden = track_columns_hidden + 1
    print(debug_prefix .. "Hidden sample effects column")
  end
  
  if verbose_debug then
    print(string.format("  Track %d summary: %d columns hidden", track_index, track_columns_hidden))
  end
  
  return track_columns_hidden
end

-- Unified Hide Unused Columns Feature
function PakettiHideAllUnusedColumns(all_tracks)
  all_tracks = all_tracks == nil and true or all_tracks -- Default to true for backward compatibility
  
  local song = renoise.song()
  local total_tracks_processed = 0
  local total_columns_hidden = 0
  
  if all_tracks then
    print("=== PAKETTI HIDE UNUSED COLUMNS DEBUG ===")
    -- Process all sequencer tracks
    for track_index = 1, song.sequencer_track_count do
      local track = song.tracks[track_index]
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local hidden = hideUnusedColumnsForTrack(track, track_index, true)
        total_tracks_processed = total_tracks_processed + 1
        total_columns_hidden = total_columns_hidden + hidden
      end
    end
    
    print(string.format("=== SUMMARY: Processed %d tracks, hidden %d total columns ===", total_tracks_processed, total_columns_hidden))
    renoise.app():show_status(string.format("Hide Unused Columns: processed %d tracks, hidden %d columns", total_tracks_processed, total_columns_hidden))
  else
    -- Process only selected track
    local track = song.selected_track
    local track_index = song.selected_track_index
    
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      renoise.app():show_status("Selected track is not a sequencer track")
      return
    end
    
    print(string.format("=== PROCESSING SELECTED TRACK %d: %s ===", track_index, track.name))
    
    local hidden = hideUnusedColumnsForTrack(track, track_index, false)
    total_columns_hidden = hidden
    total_tracks_processed = 1
    
    print(string.format("=== SELECTED TRACK SUMMARY: %d columns hidden ===", total_columns_hidden))
    renoise.app():show_status(string.format("Hide Unused Columns (Selected Track): hidden %d columns", total_columns_hidden))
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Hide All Unused Columns (All Tracks)", invoke=function() PakettiHideAllUnusedColumns() end}
renoise.tool():add_keybinding{name="Global:Paketti:Hide All Unused Columns (Selected Track)", invoke=function() PakettiHideAllUnusedColumns(false) end}

-------
-- Hide Unused Effect Columns specifically
function PakettiHideUnusedEffectColumns()
  local song = renoise.song()
  local total_tracks_processed = 0
  local total_effect_columns_hidden = 0
  
  print("=== PAKETTI HIDE UNUSED EFFECT COLUMNS DEBUG ===")
  
  -- Process all sequencer tracks
  for track_index = 1, song.sequencer_track_count do
    local track = song.tracks[track_index]
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      print(string.format("Processing Track %d: %s", track_index, track.name))
      
      -- Initialize effect column usage tracking
      local effect_columns_used = {}
      for col = 1, track.max_effect_columns do
        effect_columns_used[col] = false
      end
      
      -- Scan all patterns for this track
      for pattern_index = 1, #song.patterns do
        local pattern = song.patterns[pattern_index]
        
        -- Skip empty patterns to optimize performance
        if not pattern.is_empty then
          local pattern_track = pattern.tracks[track_index]
          
          -- Scan all lines in this pattern
          for line_index = 1, pattern.number_of_lines do
            local line = pattern_track:line(line_index)
            
            -- Check effect columns
            for col = 1, #line.effect_columns do
              local effect_col = line.effect_columns[col]
              if effect_col.number_string ~= "00" or effect_col.amount_value ~= 0 then
                effect_columns_used[col] = true
              end
            end
          end
        end
      end
      
      -- Hide unused effect columns (count from the end)
      local last_used_effect_col = 0
      for col = track.max_effect_columns, 1, -1 do
        if effect_columns_used[col] then
          last_used_effect_col = col
          break
        end
      end
      
      if last_used_effect_col < track.visible_effect_columns then
        local old_visible = track.visible_effect_columns
        track.visible_effect_columns = last_used_effect_col
        local hidden = old_visible - track.visible_effect_columns
        total_effect_columns_hidden = total_effect_columns_hidden + hidden
        print(string.format("  Effect columns: %d -> %d (hidden %d)", old_visible, track.visible_effect_columns, hidden))
      else
        print("  No unused effect columns found")
      end
      
      total_tracks_processed = total_tracks_processed + 1
    end
  end
  
  print(string.format("=== SUMMARY: Processed %d tracks, hidden %d effect columns ===", total_tracks_processed, total_effect_columns_hidden))
  renoise.app():show_status(string.format("Hide Unused Effect Columns: processed %d tracks, hidden %d effect columns", total_tracks_processed, total_effect_columns_hidden))
end

renoise.tool():add_keybinding{name="Global:Paketti:Hide Unused Effect Columns", invoke=function() PakettiHideUnusedEffectColumns() end}

-- Menu entries for Hide Unused Effect Columns
renoise.tool():add_menu_entry{name="Main Menu:View:Paketti:Hide Unused Effect Columns", invoke=function() PakettiHideUnusedEffectColumns() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Hide Unused Effect Columns", invoke=function() PakettiHideUnusedEffectColumns() end}
