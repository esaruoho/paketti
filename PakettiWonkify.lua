-- PakettiWonkify.lua
-- Wonkify patterns by randomly modifying note properties
-- Features: Pitch drift, Velocity variation, Delay drift, Row drift, 
-- Note density, Ghost notes (rolls), Retrigs, Multi-pattern chain generation

local preferences = renoise.tool().preferences
local wonkify_dialog = nil

-- Find first pattern that is both empty AND not used in the sequence
local function PakettiFindFirstEmptyPattern()
  local song = renoise.song()
  local used_in_sequence = {}
  
  -- Build a set of pattern indices used in the sequence
  for i = 1, #song.sequencer.pattern_sequence do
    used_in_sequence[song.sequencer.pattern_sequence[i]] = true
  end
  
  -- Find first pattern that is empty and not in the sequence
  for i = 1, #song.patterns do
    if song.patterns[i].is_empty and not used_in_sequence[i] then
      return i
    end
  end
  
  return nil  -- No empty pattern found
end

-- Helper function to copy all note column data
local function copy_note_column_data(src_column, dst_column)
  dst_column.note_value = src_column.note_value
  dst_column.instrument_value = src_column.instrument_value
  dst_column.volume_value = src_column.volume_value
  dst_column.panning_value = src_column.panning_value
  dst_column.delay_value = src_column.delay_value
  dst_column.effect_number_value = src_column.effect_number_value
  dst_column.effect_amount_value = src_column.effect_amount_value
end

-- Helper function to clear a note column
local function clear_note_column(column)
  column.note_value = renoise.PatternLine.EMPTY_NOTE
  column.instrument_value = renoise.PatternLine.EMPTY_INSTRUMENT
  column.volume_value = renoise.PatternLine.EMPTY_VOLUME
  column.panning_value = renoise.PatternLine.EMPTY_PANNING
  column.delay_value = renoise.PatternLine.EMPTY_DELAY
  column.effect_number_value = 0
  column.effect_amount_value = 0
end

-- Helper function to check if pitch drift should apply to a track
local function should_apply_pitch_drift(track_index, track_list_string)
  if track_list_string == nil or track_list_string == "" then
    return true  -- Apply to all tracks if no specific tracks specified
  end
  
  -- Parse comma-separated list of track indices
  for track_str in string.gmatch(track_list_string, "[^,]+") do
    local track_num = tonumber(track_str:match("^%s*(.-)%s*$"))  -- Trim whitespace
    if track_num and track_num == track_index then
      return true
    end
  end
  
  return false
end

-- Apply wonkify effects to a specific pattern
function PakettiWonkifyPattern(pattern_index)
  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  local prefs = preferences.pakettiWonkify
  
  if not pattern then
    renoise.app():show_status("Wonkify: Invalid pattern index")
    return
  end
  
  -- Count notes in pattern for diagnostic purposes (helps verify same starting state)
  local note_count = 0
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    if track.type ~= renoise.Track.TRACK_TYPE_MASTER and track.type ~= renoise.Track.TRACK_TYPE_SEND then
      local pattern_track = pattern:track(track_index)
      for line_index = 1, pattern.number_of_lines do
        local line = pattern_track:line(line_index)
        for column_index = 1, track.visible_note_columns do
          local note_column = line:note_column(column_index)
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
            note_count = note_count + 1
          end
        end
      end
    end
  end
  
  -- Apply random seed if enabled - ALWAYS set it fresh to ensure reproducibility
  if prefs.RandomSeedEnabled.value then
    local seed = prefs.RandomSeed.value
    math.randomseed(seed)
    -- Call random() a few times to "warm up" the generator (Lua quirk)
    math.random()
    math.random()
    math.random()
    -- Reset seed again after warmup for actual use
    math.randomseed(seed)
    print(string.format("Wonkify: Seed=%d, Pattern has %d notes, %d lines", seed, note_count, pattern.number_of_lines))
  else
    -- If seed not enabled, use time-based seed for variety
    math.randomseed(os.time() + os.clock() * 1000)
    print(string.format("Wonkify: Time-based seed, Pattern has %d notes, %d lines", note_count, pattern.number_of_lines))
  end
  
  local notes_affected = 0
  local delay_drifts = 0
  local row_drifts = 0
  local pitch_drifts = 0
  local velocity_changes = 0
  local notes_added = 0
  local notes_removed = 0
  local ghosts_added = 0
  local retrigs_added = 0
  
  -- Collect existing notes for density variation (adding)
  local existing_notes = {}
  
  -- Collect ghost notes to add later
  local ghost_notes_to_add = {}
  
  -- Collect row drift swaps to apply later
  local row_drift_swaps = {}
  
  -- Collect notes to remove (for density variation)
  local notes_to_remove = {}
  
  -- Collect empty positions for adding notes
  local empty_positions = {}
  
  -- First pass: collect notes, apply modifications, collect data for later operations
  for track_index = 1, #song.tracks do
    local track = song.tracks[track_index]
    
    -- Skip master and send tracks
    if track.type == renoise.Track.TRACK_TYPE_MASTER or 
       track.type == renoise.Track.TRACK_TYPE_SEND then
      -- Skip these tracks
    else
      local pattern_track = pattern:track(track_index)
      
      -- Iterate through all lines in the pattern
      for line_index = 1, pattern.number_of_lines do
        local line = pattern_track:line(line_index)
        
        -- Iterate through all note columns
        for column_index = 1, track.visible_note_columns do
          local note_column = line:note_column(column_index)
          
          -- Check if this is a valid note (not empty, not OFF)
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE and
             note_column.note_value ~= 120 then  -- 120 is NOTE_OFF
            
            notes_affected = notes_affected + 1
            
            -- Collect existing note for density variation
            table.insert(existing_notes, {
              note_value = note_column.note_value,
              instrument_value = note_column.instrument_value
            })
            
            -- Apply Delay Drift (micro-timing within row)
            if prefs.DelayDriftEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.DelayDriftPercentage.value then
                local current_delay = note_column.delay_value
                if current_delay == renoise.PatternLine.EMPTY_DELAY then
                  current_delay = 0
                end
                
                local max_drift = prefs.DelayDriftMax.value
                local drift = math.random(-max_drift, max_drift)
                local new_delay = current_delay + drift
                
                -- Clamp to valid range
                new_delay = math.max(0, math.min(255, new_delay))
                note_column.delay_value = new_delay
                
                -- Make delay column visible
                track.delay_column_visible = true
                delay_drifts = delay_drifts + 1
              end
            end
            
            -- Collect Row Drift info (apply later to avoid iteration issues)
            if prefs.RowDriftEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.RowDriftPercentage.value then
                local max_drift = prefs.RowDriftMax.value
                local drift = math.random(-max_drift, max_drift)
                local target_line = line_index + drift
                
                -- Ensure target is within pattern bounds
                if target_line >= 1 and target_line <= pattern.number_of_lines then
                  table.insert(row_drift_swaps, {
                    track_index = track_index,
                    src_line = line_index,
                    dst_line = target_line,
                    column_index = column_index
                  })
                end
              end
            end
            
            -- Apply Pitch Drift
            if prefs.PitchDriftEnabled.value then
              if should_apply_pitch_drift(track_index, prefs.PitchDriftTracks.value) then
                local dice = math.random(1, 100)
                if dice <= prefs.PitchDriftPercentage.value then
                  local max_drift = prefs.PitchDriftMax.value
                  local drift = math.random(-max_drift, max_drift)
                  local new_note = note_column.note_value + drift
                  
                  -- Clamp to valid note range (0-119, exclude OFF at 120)
                  new_note = math.max(0, math.min(119, new_note))
                  note_column.note_value = new_note
                  pitch_drifts = pitch_drifts + 1
                end
              end
            end
            
            -- Apply Velocity Variation (percentage-based)
            if prefs.VelocityEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.VelocityPercentage.value then
                local current_vol = note_column.volume_value
                if current_vol == renoise.PatternLine.EMPTY_VOLUME then
                  current_vol = 128  -- Default full volume
                end
                
                local variation = prefs.VelocityVariation.value / 100
                local change = current_vol * variation * (math.random() * 2 - 1)  -- +/- percentage
                local new_vol = math.floor(current_vol + change)
                new_vol = math.max(1, math.min(128, new_vol))
                note_column.volume_value = new_vol
                
                -- Make volume column visible
                track.volume_column_visible = true
                velocity_changes = velocity_changes + 1
              end
            end
            
            -- Note Density - Remove
            if prefs.DensityEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.DensityRemovePercentage.value then
                table.insert(notes_to_remove, {
                  track_index = track_index,
                  line_index = line_index,
                  column_index = column_index
                })
              end
            end
            
            -- Apply Retrig
            if prefs.RetrigEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.RetrigPercentage.value then
                local retrig_range = prefs.RetrigMax.value - prefs.RetrigMin.value
                local retrig_val = prefs.RetrigMin.value + math.random(0, math.max(0, retrig_range))
                
                if prefs.RetrigColumn.value == 1 then
                  -- Write to Effect Column
                  if track.visible_effect_columns < 1 then
                    track.visible_effect_columns = 1
                  end
                  local effect_column = line:effect_column(1)
                  effect_column.number_string = "0R"
                  effect_column.amount_value = retrig_val
                else
                  -- Write to Sample Effects Column
                  track.sample_effects_column_visible = true
                  note_column.effect_number_string = "0R"
                  note_column.effect_amount_value = retrig_val
                end
                
                retrigs_added = retrigs_added + 1
              end
            end
            
            -- Collect Ghost Note (Roll) info
            if prefs.GhostEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.GhostPercentage.value then
                local ghost_count = prefs.GhostCount.value
                local direction = prefs.GhostDirection.value
                local vol_start = prefs.GhostVolumeStart.value
                local vol_end = prefs.GhostVolumeEnd.value
                
                for ghost_i = 1, ghost_count do
                  local ghost_line
                  local ghost_vol
                  
                  if direction == 1 then
                    -- Before (build-up): place ghosts before the note, volume increasing
                    ghost_line = line_index - (ghost_count - ghost_i + 1)
                    ghost_vol = vol_start + (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  else
                    -- After (trail-off): place ghosts after the note, volume decreasing
                    ghost_line = line_index + ghost_i
                    ghost_vol = vol_end - (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  end
                  
                  -- Ensure ghost line is within pattern bounds
                  if ghost_line >= 1 and ghost_line <= pattern.number_of_lines then
                    local actual_vol = math.floor(128 * ghost_vol / 100)
                    actual_vol = math.max(1, math.min(128, actual_vol))
                    
                    table.insert(ghost_notes_to_add, {
                      track_index = track_index,
                      line_index = ghost_line,
                      column_index = column_index,
                      note_value = note_column.note_value,
                      instrument_value = note_column.instrument_value,
                      volume = actual_vol
                    })
                  end
                end
              end
            end
          else
            -- Empty position - collect for density add
            if prefs.DensityEnabled.value and note_column.note_value == renoise.PatternLine.EMPTY_NOTE then
              table.insert(empty_positions, {
                track_index = track_index,
                line_index = line_index,
                column_index = column_index
              })
            end
          end
        end
      end
    end
  end
  
  -- Apply Row Drift swaps
  for _, swap in ipairs(row_drift_swaps) do
    local pattern_track = pattern:track(swap.track_index)
    local src_line = pattern_track:line(swap.src_line)
    local dst_line = pattern_track:line(swap.dst_line)
    local src_column = src_line:note_column(swap.column_index)
    local dst_column = dst_line:note_column(swap.column_index)
    
    -- Store source data temporarily
    local temp_note = src_column.note_value
    local temp_instrument = src_column.instrument_value
    local temp_volume = src_column.volume_value
    local temp_panning = src_column.panning_value
    local temp_delay = src_column.delay_value
    local temp_effect_num = src_column.effect_number_value
    local temp_effect_amt = src_column.effect_amount_value
    
    -- Copy destination to source
    copy_note_column_data(dst_column, src_column)
    
    -- Put source data in destination
    dst_column.note_value = temp_note
    dst_column.instrument_value = temp_instrument
    dst_column.volume_value = temp_volume
    dst_column.panning_value = temp_panning
    dst_column.delay_value = temp_delay
    dst_column.effect_number_value = temp_effect_num
    dst_column.effect_amount_value = temp_effect_amt
    
    row_drifts = row_drifts + 1
  end
  
  -- Remove notes for density variation
  for _, pos in ipairs(notes_to_remove) do
    local pattern_track = pattern:track(pos.track_index)
    local line = pattern_track:line(pos.line_index)
    local note_column = line:note_column(pos.column_index)
    clear_note_column(note_column)
    notes_removed = notes_removed + 1
  end
  
  -- Add notes for density variation (to random empty positions)
  if prefs.DensityEnabled.value and #existing_notes > 0 and #empty_positions > 0 then
    for _, pos in ipairs(empty_positions) do
      local dice = math.random(1, 100)
      if dice <= prefs.DensityAddPercentage.value then
        local pattern_track = pattern:track(pos.track_index)
        local line = pattern_track:line(pos.line_index)
        local note_column = line:note_column(pos.column_index)
        
        -- Pick a random existing note
        local source = existing_notes[math.random(1, #existing_notes)]
        note_column.note_value = source.note_value
        note_column.instrument_value = source.instrument_value
        notes_added = notes_added + 1
      end
    end
  end
  
  -- Add ghost notes (rolls)
  for _, ghost in ipairs(ghost_notes_to_add) do
    local track = song.tracks[ghost.track_index]
    local pattern_track = pattern:track(ghost.track_index)
    local line = pattern_track:line(ghost.line_index)
    local note_column = line:note_column(ghost.column_index)
    
    -- Only add ghost if the target cell is empty
    if note_column.note_value == renoise.PatternLine.EMPTY_NOTE then
      note_column.note_value = ghost.note_value
      note_column.instrument_value = ghost.instrument_value
      note_column.volume_value = ghost.volume
      
      -- Make volume column visible
      track.volume_column_visible = true
      ghosts_added = ghosts_added + 1
    end
  end
  
  local status_msg = string.format(
    "Wonkified: %d notes | DelayDrift:%d RowDrift:%d Pitch:%d Vel:%d +Notes:%d -Notes:%d Ghost:%d Retrig:%d",
    notes_affected, delay_drifts, row_drifts, pitch_drifts, velocity_changes, 
    notes_added, notes_removed, ghosts_added, retrigs_added)
  renoise.app():show_status(status_msg)
  print(status_msg)
end

-- Wonkify current pattern in place
function PakettiWonkifyCurrentPattern()
  local song = renoise.song()
  local current_pattern_index = song.selected_pattern_index
  
  PakettiWonkifyPattern(current_pattern_index)
end

-- Duplicate pattern to new empty pattern and then wonkify it
function PakettiWonkifyDuplicatePattern()
  local song = renoise.song()
  local sequencer = song.sequencer
  local current_pattern_index = song.selected_pattern_index
  local current_sequence_index = song.selected_sequence_index
  
  -- Find first empty pattern not in sequence, or create new one
  local empty_pattern_index = PakettiFindFirstEmptyPattern()
  
  if not empty_pattern_index then
    -- No empty pattern found, use insert_new_pattern_at which creates a new one
    local new_sequence_index = current_sequence_index + 1
    empty_pattern_index = sequencer:insert_new_pattern_at(new_sequence_index)
  else
    -- Insert the empty pattern into the sequence after current position
    local new_sequence_index = current_sequence_index + 1
    sequencer:insert_sequence_at(new_sequence_index, empty_pattern_index)
  end
  
  -- Get the new sequence index (always current + 1)
  local new_sequence_index = current_sequence_index + 1
  
  -- Copy content from current pattern to the target pattern
  song.patterns[empty_pattern_index]:copy_from(song.patterns[current_pattern_index])
  
  -- Set pattern name
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[empty_pattern_index].name = original_name .. " (Wonky)"
  
  -- Copy mute states from original sequence slot to the new one
  for track_index = 1, #song.tracks do
    local is_muted = sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  
  -- Copy automation data
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[empty_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  
  -- Jump to the new sequence position
  song.selected_sequence_index = new_sequence_index
  
  -- Now wonkify the duplicated pattern
  PakettiWonkifyPattern(empty_pattern_index)
  
  renoise.app():show_status("Duplicated and wonkified pattern to sequence " .. new_sequence_index)
end

-- Generate a chain of wonkified patterns (each is a variation of the previous)
function PakettiWonkifyGenerateChain()
  local prefs = preferences.pakettiWonkify
  local count = prefs.PatternCount.value
  local original_seed = prefs.RandomSeed.value
  
  for i = 1, count do
    -- Duplicate and wonkify the current pattern
    PakettiWonkifyDuplicatePattern()
    
    -- Increment seed for next variation (if seed enabled)
    if prefs.RandomSeedEnabled.value then
      prefs.RandomSeed.value = prefs.RandomSeed.value + 1
    end
  end
  
  -- Restore original seed
  prefs.RandomSeed.value = original_seed
  
  renoise.app():show_status("Generated " .. count .. " wonkified patterns in chain")
end

-- Dialog for Wonkify settings
function PakettiWonkifyDialog()
  -- Toggle behavior - close if already open
  if wonkify_dialog and wonkify_dialog.visible then
    wonkify_dialog:close()
    wonkify_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  local prefs = preferences.pakettiWonkify
  
  local slider_width = 150
  local label_width = 120
  local value_width = 40
  local group_width = 360
  
  -- Helper function to create a labeled slider row
  local function create_slider_row(label, min_val, max_val, pref, suffix)
    suffix = suffix or ""
    local value_text = vb:text{
      text = string.format("%d%s", pref.value, suffix),
      width = value_width
    }
    return vb:row{
      vb:text{text = label, width = label_width},
      vb:slider{
        min = min_val,
        max = max_val,
        value = pref.value,
        width = slider_width,
        notifier = function(value)
          pref.value = math.floor(value)
          value_text.text = string.format("%d%s", math.floor(value), suffix)
        end
      },
      value_text
    }
  end
  
  local dialog_content = vb:column{
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
    
    -- Generation Settings Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:text{text = "Generation Settings", font = "bold", style = "strong"},
      vb:row{
        vb:checkbox{
          value = prefs.RandomSeedEnabled.value,
          notifier = function(value) prefs.RandomSeedEnabled.value = value end
        },
        vb:text{text = "Random Seed"},
        vb:valuebox{
          min = 1,
          max = 999999,
          value = prefs.RandomSeed.value,
          width = 80,
          notifier = function(value) prefs.RandomSeed.value = value end
        },
        vb:button{
          text = "New",
          width = 40,
          notifier = function()
            -- Use time-based seed generation to avoid interfering with main random state
            local new_seed = (os.time() % 900000) + math.floor(os.clock() * 1000) % 99999
            prefs.RandomSeed.value = math.max(1, math.min(999999, new_seed))
          end
        }
      },
      vb:row{
        vb:text{text = "Pattern Count", width = label_width},
        vb:valuebox{
          min = 1,
          max = 16,
          value = prefs.PatternCount.value,
          width = 60,
          notifier = function(value) prefs.PatternCount.value = value end
        },
        vb:text{text = "(for chain generation)"}
      }
    },
    
    -- Rhythm Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:text{text = "Rhythm", font = "bold", style = "strong"},
      
      -- Delay Drift
      vb:row{
        vb:checkbox{
          value = prefs.DelayDriftEnabled.value,
          notifier = function(value) prefs.DelayDriftEnabled.value = value end
        },
        vb:text{text = "Delay Drift (ticks within row)"}
      },
      create_slider_row("Percentage", 0, 100, prefs.DelayDriftPercentage, "%"),
      create_slider_row("Max Ticks (+/-)", 0, 255, prefs.DelayDriftMax),
      
      vb:space{height = 5},
      
      -- Row Drift
      vb:row{
        vb:checkbox{
          value = prefs.RowDriftEnabled.value,
          notifier = function(value) prefs.RowDriftEnabled.value = value end
        },
        vb:text{text = "Row Drift (swap positions)"}
      },
      create_slider_row("Percentage", 0, 100, prefs.RowDriftPercentage, "%"),
      create_slider_row("Max Rows (+/-)", 1, 16, prefs.RowDriftMax)
    },
    
    -- Pitch Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.PitchDriftEnabled.value,
          notifier = function(value) prefs.PitchDriftEnabled.value = value end
        },
        vb:text{text = "Pitch Drift (semitones)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.PitchDriftPercentage, "%"),
      create_slider_row("Max Semitones (+/-)", 1, 12, prefs.PitchDriftMax),
      vb:row{
        vb:text{text = "Apply to Tracks", width = label_width},
        vb:textfield{
          value = prefs.PitchDriftTracks.value,
          width = slider_width,
          tooltip = "Comma-separated track numbers (e.g. '1,2,3') or empty for all",
          notifier = function(value) prefs.PitchDriftTracks.value = value end
        }
      }
    },
    
    -- Velocity Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.VelocityEnabled.value,
          notifier = function(value) prefs.VelocityEnabled.value = value end
        },
        vb:text{text = "Velocity Variation", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.VelocityPercentage, "%"),
      create_slider_row("Max Change (+/-)", 1, 100, prefs.VelocityVariation, "%")
    },
    
    -- Density Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.DensityEnabled.value,
          notifier = function(value) prefs.DensityEnabled.value = value end
        },
        vb:text{text = "Note Density Variation", font = "bold", style = "strong"}
      },
      create_slider_row("Add Notes %", 0, 50, prefs.DensityAddPercentage, "%"),
      create_slider_row("Remove Notes %", 0, 50, prefs.DensityRemovePercentage, "%")
    },
    
    -- Ghost Notes Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.GhostEnabled.value,
          notifier = function(value) prefs.GhostEnabled.value = value end
        },
        vb:text{text = "Ghost Notes (Rolls)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.GhostPercentage, "%"),
      create_slider_row("Ghost Count", 1, 4, prefs.GhostCount),
      vb:row{
        vb:text{text = "Direction", width = label_width},
        vb:popup{
          items = {"Build-up (before)", "Trail-off (after)"},
          value = prefs.GhostDirection.value,
          width = slider_width,
          notifier = function(value) prefs.GhostDirection.value = value end
        }
      },
      create_slider_row("Volume Start", 1, 100, prefs.GhostVolumeStart, "%"),
      create_slider_row("Volume End", 1, 100, prefs.GhostVolumeEnd, "%")
    },
    
    -- Retrig Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = group_width,
      
      vb:row{
        vb:checkbox{
          value = prefs.RetrigEnabled.value,
          notifier = function(value) prefs.RetrigEnabled.value = value end
        },
        vb:text{text = "Retrig (0Rxx)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.RetrigPercentage, "%"),
      create_slider_row("Min Retrig", 1, 255, prefs.RetrigMin),
      create_slider_row("Max Retrig", 1, 255, prefs.RetrigMax),
      vb:row{
        vb:text{text = "Column", width = label_width},
        vb:popup{
          items = {"Effect Column", "Sample FX Column"},
          value = prefs.RetrigColumn.value,
          width = slider_width,
          notifier = function(value) prefs.RetrigColumn.value = value end
        }
      }
    },
    
    -- Action Buttons
    vb:horizontal_aligner{
      mode = "center",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      
      vb:button{
        text = "Wonkify Current",
        width = 110,
        notifier = function()
          PakettiWonkifyCurrentPattern()
        end
      },
      vb:button{
        text = "Duplicate & Wonkify",
        width = 120,
        notifier = function()
          PakettiWonkifyDuplicatePattern()
        end
      },
      vb:button{
        text = "Generate Chain",
        width = 110,
        notifier = function()
          PakettiWonkifyGenerateChain()
        end
      }
    }
  }
  
  local keyhandler = create_keyhandler_for_dialog(
    function() return wonkify_dialog end,
    function(value) wonkify_dialog = value end
  )
  
  wonkify_dialog = renoise.app():show_custom_dialog("Paketti Wonkify", dialog_content, keyhandler)
  
  -- Ensure Renoise gets keyboard focus back
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Keybindings
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Generate Chain", invoke=PakettiWonkifyGenerateChain}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

-- MIDI Mappings
renoise.tool():add_midi_mapping{name="Paketti:Wonkify Current Pattern",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyCurrentPattern() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Duplicate & Wonkify Pattern",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyDuplicatePattern() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Generate Chain",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyGenerateChain() 
    end 
  end
}

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Dialog",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyDialog() 
    end 
  end
}
