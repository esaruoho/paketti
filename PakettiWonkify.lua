-- PakettiWonkify.lua
-- Wonkify patterns by randomly modifying note properties (delay, volume, panning)
-- and adding effects (retrigs, ghost notes/rolls, rhythm drift)

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

-- Apply wonkify effects to a specific pattern
function PakettiWonkifyPattern(pattern_index)
  local song = renoise.song()
  local pattern = song.patterns[pattern_index]
  local prefs = preferences.pakettiWonkify
  
  if not pattern then
    renoise.app():show_status("Wonkify: Invalid pattern index")
    return
  end
  
  -- Apply random seed if enabled
  if prefs.RandomSeedEnabled.value then
    math.randomseed(prefs.RandomSeed.value)
    print("Wonkify: Using random seed " .. prefs.RandomSeed.value)
  end
  
  local notes_affected = 0
  local delays_modified = 0
  local volumes_modified = 0
  local pans_modified = 0
  local retrigs_added = 0
  local ghosts_added = 0
  local drifts_applied = 0
  
  -- Collect ghost notes to add later (to avoid modifying while iterating)
  local ghost_notes_to_add = {}
  
  -- Collect drift swaps to apply later
  local drift_swaps = {}
  
  -- First pass: collect notes and determine modifications
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
            
            -- Apply delay modification
            if prefs.DelayEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.DelayPercentage.value then
                local delay_range = prefs.DelayMax.value - prefs.DelayMin.value
                local delay_offset = math.random(0, math.max(0, delay_range))
                local new_delay = prefs.DelayMin.value + delay_offset
                
                -- Randomly add or subtract from existing delay
                local current_delay = note_column.delay_value
                if current_delay == renoise.PatternLine.EMPTY_DELAY then
                  current_delay = 0
                end
                
                -- Randomly decide to add or subtract
                if math.random(1, 2) == 1 then
                  new_delay = current_delay + new_delay
                else
                  new_delay = current_delay - new_delay
                end
                
                -- Clamp to valid range
                new_delay = math.max(0, math.min(255, new_delay))
                note_column.delay_value = new_delay
                
                -- Make delay column visible
                track.delay_column_visible = true
                delays_modified = delays_modified + 1
              end
            end
            
            -- Apply volume modification
            if prefs.VolumeEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.VolumePercentage.value then
                local vol_range = prefs.VolumeMax.value - prefs.VolumeMin.value
                local new_vol = prefs.VolumeMin.value + math.random(0, math.max(0, vol_range))
                
                -- Clamp to valid range (00-80 hex = 0-128 dec)
                new_vol = math.max(0, math.min(128, new_vol))
                note_column.volume_value = new_vol
                
                -- Make volume column visible
                track.volume_column_visible = true
                volumes_modified = volumes_modified + 1
              end
            end
            
            -- Apply panning modification
            if prefs.PanEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.PanPercentage.value then
                local pan_range = prefs.PanMax.value - prefs.PanMin.value
                local new_pan = prefs.PanMin.value + math.random(0, math.max(0, pan_range))
                
                -- Clamp to valid range (00-80 hex = 0-128 dec)
                new_pan = math.max(0, math.min(128, new_pan))
                note_column.panning_value = new_pan
                
                -- Make panning column visible
                track.panning_column_visible = true
                pans_modified = pans_modified + 1
              end
            end
            
            -- Apply retrig
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
            
            -- Collect rhythm drift info
            if prefs.DriftEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.DriftPercentage.value then
                local drift_range = prefs.DriftMax.value - prefs.DriftMin.value
                local drift_amount = prefs.DriftMin.value + math.random(0, math.max(0, drift_range))
                
                -- Randomly drift forward or backward
                if math.random(1, 2) == 1 then
                  drift_amount = -drift_amount
                end
                
                local target_line = line_index + drift_amount
                
                -- Ensure target is within pattern bounds
                if target_line >= 1 and target_line <= pattern.number_of_lines then
                  table.insert(drift_swaps, {
                    track_index = track_index,
                    src_line = line_index,
                    dst_line = target_line,
                    column_index = column_index
                  })
                end
              end
            end
            
            -- Collect ghost note (roll) info
            if prefs.GhostEnabled.value then
              local dice = math.random(1, 100)
              if dice <= prefs.GhostPercentage.value then
                local ghost_count = prefs.GhostCount.value
                local direction = prefs.GhostDirection.value  -- 1=Before (build-up), 2=After (trail-off)
                local vol_start = prefs.GhostVolumeStart.value
                local vol_end = prefs.GhostVolumeEnd.value
                
                for ghost_i = 1, ghost_count do
                  local ghost_line
                  local ghost_vol
                  
                  if direction == 1 then
                    -- Before (build-up): place ghosts before the note, volume increasing
                    ghost_line = line_index - (ghost_count - ghost_i + 1)
                    -- Interpolate volume: first ghost gets vol_start, last ghost gets vol_end
                    ghost_vol = vol_start + (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  else
                    -- After (trail-off): place ghosts after the note, volume decreasing
                    ghost_line = line_index + ghost_i
                    -- Interpolate volume: first ghost gets vol_end, last ghost gets vol_start
                    ghost_vol = vol_end - (vol_end - vol_start) * ((ghost_i - 1) / math.max(1, ghost_count - 1))
                  end
                  
                  -- Ensure ghost line is within pattern bounds
                  if ghost_line >= 1 and ghost_line <= pattern.number_of_lines then
                    -- Convert percentage to actual volume value (0-128)
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
          end
        end
      end
    end
  end
  
  -- Apply rhythm drift swaps
  for _, swap in ipairs(drift_swaps) do
    local track = song.tracks[swap.track_index]
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
    
    drifts_applied = drifts_applied + 1
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
  
  local status_msg = string.format("Wonkified: %d notes, Delay:%d, Vol:%d, Pan:%d, Retrig:%d, Drift:%d, Ghost:%d",
    notes_affected, delays_modified, volumes_modified, pans_modified, retrigs_added, drifts_applied, ghosts_added)
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
    
    -- Random Seed Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
      vb:row{
        vb:checkbox{
          value = prefs.RandomSeedEnabled.value,
          notifier = function(value) prefs.RandomSeedEnabled.value = value end
        },
        vb:text{text = "Random Seed", font = "bold", style = "strong"},
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
            prefs.RandomSeed.value = math.random(1, 999999)
          end
        }
      }
    },
    
    -- Delay Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
      vb:row{
        vb:checkbox{
          value = prefs.DelayEnabled.value,
          notifier = function(value) prefs.DelayEnabled.value = value end
        },
        vb:text{text = "Delay Modification", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.DelayPercentage, "%"),
      create_slider_row("Min Offset", 0, 255, prefs.DelayMin),
      create_slider_row("Max Offset", 0, 255, prefs.DelayMax)
    },
    
    -- Volume Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
      vb:row{
        vb:checkbox{
          value = prefs.VolumeEnabled.value,
          notifier = function(value) prefs.VolumeEnabled.value = value end
        },
        vb:text{text = "Volume Modification", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.VolumePercentage, "%"),
      create_slider_row("Min Volume", 0, 128, prefs.VolumeMin),
      create_slider_row("Max Volume", 0, 128, prefs.VolumeMax)
    },
    
    -- Panning Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
      vb:row{
        vb:checkbox{
          value = prefs.PanEnabled.value,
          notifier = function(value) prefs.PanEnabled.value = value end
        },
        vb:text{text = "Panning Modification", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.PanPercentage, "%"),
      create_slider_row("Min Pan", 0, 128, prefs.PanMin),
      create_slider_row("Max Pan", 0, 128, prefs.PanMax)
    },
    
    -- Retrig Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
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
    
    -- Rhythm Drift Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
      vb:row{
        vb:checkbox{
          value = prefs.DriftEnabled.value,
          notifier = function(value) prefs.DriftEnabled.value = value end
        },
        vb:text{text = "Rhythm Drift (Swap)", font = "bold", style = "strong"}
      },
      create_slider_row("Percentage", 0, 100, prefs.DriftPercentage, "%"),
      create_slider_row("Min Rows", 1, 16, prefs.DriftMin),
      create_slider_row("Max Rows", 1, 32, prefs.DriftMax)
    },
    
    -- Ghost Notes (Rolls) Section
    vb:column{
      style = "group",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      width = 350,
      
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
    
    -- Action Buttons
    vb:horizontal_aligner{
      mode = "center",
      margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
      
      vb:button{
        text = "Wonkify Current Pattern",
        width = 160,
        notifier = function()
          PakettiWonkifyCurrentPattern()
        end
      },
      vb:button{
        text = "Duplicate & Wonkify",
        width = 160,
        notifier = function()
          PakettiWonkifyDuplicatePattern()
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
renoise.tool():add_keybinding{name="Global:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Wonkify Dialog", invoke=PakettiWonkifyDialog}

renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Wonkify Current Pattern", invoke=PakettiWonkifyCurrentPattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate & Wonkify Pattern", invoke=PakettiWonkifyDuplicatePattern}
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

renoise.tool():add_midi_mapping{name="Paketti:Wonkify Dialog",
  invoke=function(message) 
    if message:is_trigger() then 
      PakettiWonkifyDialog() 
    end 
  end
}
