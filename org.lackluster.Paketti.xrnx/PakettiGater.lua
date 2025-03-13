local vb = renoise.ViewBuilder()
local dialog
local checkboxes = {}
local retrig_checkboxes = {}
local playback_checkboxes = {}
local num_checkboxes = 16
local max_rows = 64
local column_choice = "FX Column"
local retrig_value = 4
local retrig_column_choice = "FX Column"
local active_steps_volume = num_checkboxes
local active_steps_retrig = num_checkboxes
local active_steps_playback = num_checkboxes
local panning_left_checkboxes = {}
local panning_center_checkboxes = {}
local panning_right_checkboxes = {}
local panning_buttons = {}
local active_steps_panning = num_checkboxes
local panning_column_choice = "FX Column"
local initializing = false -- Flag to control printing during initialization or fetching

-- Add at the top with other globals
local auto_grab = false
local previous_track_index = nil
local track_notifier = nil


-- Colors for buttons
local normal_color = nil
local highlight_color = {0x22, 0xaa, 0xff}

-- Initialize buttons and checkboxes
local buttons = {}
local retrig_buttons = {}
local playback_buttons = {}

-- Paketti Gater Device Script

local function initialize_checkboxes(count)
  checkboxes = {}
  retrig_checkboxes = {}
  playback_checkboxes = {}
  buttons = {}
  retrig_buttons = {}
  playback_buttons = {}
  panning_left_checkboxes = {}
  panning_center_checkboxes = {}
  panning_right_checkboxes = {}
  panning_buttons = {}

  for i = 1, count do
    local is_highlight = (i == 1 or i == 5 or i == 9 or i == 13)
    buttons[i] = vb:button {
      text = string.format("%02d", i),
      width = 30,
      color = is_highlight and highlight_color or normal_color
    }
    retrig_buttons[i] = vb:button {
      text = string.format("%02d", i),
      width = 30,
      color = is_highlight and highlight_color or normal_color
    }
    playback_buttons[i] = vb:button {
      text = string.format("%02d", i),
      width = 30,
      color = is_highlight and highlight_color or normal_color
    }
    checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if not initializing then
          insert_commands()
        end
      end
    }
    retrig_checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if not initializing then
          insert_commands()
        end
      end
    }
    playback_checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if not initializing then
          insert_commands()
        end
      end
    }
  end

  for i = 1, count do
    panning_left_checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if panning_left_checkboxes[i].value then
          panning_center_checkboxes[i].value = false
          panning_right_checkboxes[i].value = false
        end
        if not initializing then
          insert_commands()
        end
      end
    }
    panning_center_checkboxes[i] = vb:checkbox {
      value = true,
      width = 30,
      notifier = function()
        if panning_center_checkboxes[i].value then
          panning_left_checkboxes[i].value = false
          panning_right_checkboxes[i].value = false
        end
        if not initializing then
          insert_commands()
        end
      end
    }
    panning_right_checkboxes[i] = vb:checkbox {
      value = false,
      width = 30,
      notifier = function()
        if panning_right_checkboxes[i].value then
          panning_left_checkboxes[i].value = false
          panning_center_checkboxes[i].value = false
        end
        if not initializing then
          insert_commands()
        end
      end
    }
    panning_buttons[i] = vb:button {
      text = string.format("%02d", i),
      width = 30,
      color = (i == 1 or i == 5 or i == 9 or i == 13) and highlight_color or normal_color
    }
  end
end

initialize_checkboxes(num_checkboxes)

-- Set active steps based on the valuebox
local function set_active_steps_volume(value)
  active_steps_volume = value
  renoise.app():show_status("Volume Gater: Step count set to " .. value)
  if not initializing then
    insert_commands()
  end
end

local function set_active_steps_retrig(value)
  active_steps_retrig = value
  if not initializing then
    insert_commands()
  end
end

local function set_active_steps_playback(value)
  active_steps_playback = value
  if not initializing then
    insert_commands()
  end
end

local function set_active_steps_panning(value)
  active_steps_panning = value
  if not initializing then
    insert_commands()
  end
end

-- Receive Volume checkboxes state
local function receive_volume_checkboxes()
  if not renoise.song() then return end

  initializing = true -- Halt printing during fetching

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track
  local visible_note_columns = track.visible_note_columns

  for i = 1, num_checkboxes do
    local line_index = 1 + i -1
    if line_index <= max_rows then
      local line = pattern:track(track_index):line(line_index)
      if column_choice == "FX Column" then
        checkboxes[i].value = (line.effect_columns[1].number_string == "0C" and line.effect_columns[1].amount_string == "0F")
      elseif column_choice == "Volume Column" then
        checkboxes[i].value = false
        for j = 1, visible_note_columns do
          local note_column = line:note_column(j)
          if note_column.volume_string == "80" then
            checkboxes[i].value = true
            break
          end
        end
      elseif column_choice == "FX Column (L00)" then
        checkboxes[i].value = (line.effect_columns[1].number_string == "0L" and line.effect_columns[1].amount_string == "C0")
      end
    end
  end
  
  -- IMPORTANT: Don't call insert_commands() here as it would overwrite other effects
  -- Instead, only write the volume pattern to the first active_steps_volume rows
  
  local pattern_length = pattern.number_of_lines
  
  -- Only write volume effects, don't clear other effects
  local any_checkbox_checked = false
  for i = 1, num_checkboxes do
    if checkboxes[i].value then
      any_checkbox_checked = true
      break
    end
  end

  if any_checkbox_checked then
    -- Only write up to active_steps_volume
    for i = 1, active_steps_volume do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_volume) + 1
      
      if column_choice == "FX Column" then
        if checkboxes[checkbox_idx].value then
          line.effect_columns[1].number_string = "0C"
          line.effect_columns[1].amount_string = "0F"
        else
          line.effect_columns[1].number_string = "0C"
          line.effect_columns[1].amount_string = "00"
        end
      elseif column_choice == "Volume Column" then
        track.volume_column_visible = true
        for j = 1, visible_note_columns do
          local note_column = line:note_column(j)
          -- Only update if not used by retrig
          if retrig_column_choice ~= "Volume Column" or 
             string.sub(note_column.volume_string, 1, 1) ~= "R" then
            if checkboxes[checkbox_idx].value then
              note_column.volume_string = "80"
            else
              note_column.volume_string = "00"
            end
          end
        end
      elseif column_choice == "FX Column (L00)" then
        if checkboxes[checkbox_idx].value then
          line.effect_columns[1].number_string = "0L"
          line.effect_columns[1].amount_string = "C0"
        else
          line.effect_columns[1].number_string = "0L"
          line.effect_columns[1].amount_string = "00"
        end
      end
    end
    
    -- Replicate the volume pattern to the rest of the pattern
    for row = active_steps_volume + 1, pattern_length do
      local dest_line = pattern:track(track_index):line(row)
      local source_row = ((row - 1) % active_steps_volume) + 1
      local source_line = pattern:track(track_index):line(source_row)
      
      if column_choice == "FX Column" or column_choice == "FX Column (L00)" then
        dest_line.effect_columns[1]:copy_from(source_line.effect_columns[1])
      elseif column_choice == "Volume Column" then
        for col = 1, visible_note_columns do
          -- Only copy if not a retrig value
          if retrig_column_choice ~= "Volume Column" or 
             string.sub(source_line:note_column(col).volume_string, 1, 1) ~= "R" then
            dest_line:note_column(col).volume_string = source_line:note_column(col).volume_string
          end
        end
      end
    end
  end
  
  initializing = false
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Received Volume Gater pattern")
end

-- Receive Retrig checkboxes state
local function receive_retrig_checkboxes()
  if not renoise.song() then return end

  initializing = true

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track
  local visible_note_columns = track.visible_note_columns
  local pattern_length = pattern.number_of_lines

  -- First, read the current pattern to set checkbox states
  for i = 1, num_checkboxes do
    local line_index = 1 + i - 1
    if line_index <= max_rows then
      local line = pattern:track(track_index):line(line_index)
      if retrig_column_choice == "FX Column" then
        retrig_checkboxes[i].value = (line.effect_columns[2].number_string == "0R")
      elseif retrig_column_choice == "Volume Column" then
        retrig_checkboxes[i].value = false
        for j = 1, visible_note_columns do
          local note_column = line:note_column(j)
          if string.sub(note_column.volume_string, 1, 1) == "R" then
            retrig_checkboxes[i].value = true
            break
          end
        end
      elseif retrig_column_choice == "Panning Column" then
        renoise.song().selected_track.panning_column_visible = true
        retrig_checkboxes[i].value = false
        for j = 1, visible_note_columns do
          local note_column = line:note_column(j)
          if string.sub(note_column.panning_string, 1, 1) == "R" then
            retrig_checkboxes[i].value = true
            break
          end
        end
      end
    end
  end
  
  -- Now write the retrig pattern based on checkboxes, but don't call insert_commands()
  -- Clear the retrig columns first
  if retrig_column_choice == "FX Column" then
    clear_retrig()
  elseif retrig_column_choice == "Volume Column" then
    -- Only clear volume column if not used by volume gater
    if column_choice ~= "Volume Column" then
      clear_volume_column()
    end
  elseif retrig_column_choice == "Panning Column" then
    -- Only clear panning column if not used by panning gater
    if panning_column_choice ~= "Panning Column" then
      clear_panning_column()
    end
  end
  
  -- Write retrig pattern based on checkboxes
  local retrig_is_empty = true
  for i = 1, num_checkboxes do
    if retrig_checkboxes[i].value then
      retrig_is_empty = false
      break
    end
  end

  if not retrig_is_empty then
    -- Only write up to active_steps_retrig
    for i = 1, active_steps_retrig do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_retrig) + 1

      if retrig_checkboxes[checkbox_idx].value then
        if retrig_column_choice == "FX Column" then
          line.effect_columns[2].number_string = "0R"
          line.effect_columns[2].amount_string = string.format("%02X", retrig_value)
        elseif retrig_column_choice == "Volume Column" then
          track.volume_column_visible = true
          for j = 1, visible_note_columns do
            local note_column = line:note_column(j)
            -- Only update if not used by volume gater
            if column_choice ~= "Volume Column" or 
               note_column.volume_string == "" or 
               note_column.volume_string == "00" or 
               note_column.volume_string == "80" then
              note_column.volume_string = string.format("R%X", retrig_value)
            end
          end
        elseif retrig_column_choice == "Panning Column" then
          renoise.song().selected_track.panning_column_visible = true
          for j = 1, visible_note_columns do
            local note_column = line:note_column(j)
            -- Only update if not used by panning gater
            if panning_column_choice ~= "Panning Column" or 
               note_column.panning_string == "" or 
               note_column.panning_string == "40" or 
               note_column.panning_string == "00" or 
               note_column.panning_string == "80" then
              note_column.panning_string = string.format("R%X", retrig_value)
            end
          end
        end
      end
    end
    
    -- Replicate the retrig pattern to the rest of the pattern
    for row = active_steps_retrig + 1, pattern_length do
      local dest_line = pattern:track(track_index):line(row)
      local source_row = ((row - 1) % active_steps_retrig) + 1
      local source_line = pattern:track(track_index):line(source_row)
      
      if retrig_column_choice == "FX Column" then
        dest_line.effect_columns[2]:copy_from(source_line.effect_columns[2])
      elseif retrig_column_choice == "Volume Column" then
        for col = 1, visible_note_columns do
          if string.sub(source_line:note_column(col).volume_string, 1, 1) == "R" then
            dest_line:note_column(col).volume_string = source_line:note_column(col).volume_string
          end
        end
      elseif retrig_column_choice == "Panning Column" then
        for col = 1, visible_note_columns do
          if string.sub(source_line:note_column(col).panning_string, 1, 1) == "R" then
            dest_line:note_column(col).panning_string = source_line:note_column(col).panning_string
          end
        end
      end
    end
  end
  
  initializing = false
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Received Retrig Gater pattern")
end

-- Receive Playback checkboxes state
local function receive_playback_checkboxes()
  if not renoise.song() then return end

  initializing = true

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track
  local pattern_length = pattern.number_of_lines

  -- First, read the current pattern to set checkbox states
  for i = 1, num_checkboxes do
    local line_index = 1 + i - 1
    if line_index <= max_rows then
      local line = pattern:track(track_index):line(line_index)
      playback_checkboxes[i].value = (line.effect_columns[3].number_string == "0B" and line.effect_columns[3].amount_string == "00")
    end
  end
  
  -- IMPORTANT: Don't call clear_playback_effect() as it would wipe the content
  -- Instead, only update the existing pattern without clearing
  
  -- Write playback pattern based on checkboxes
  local any_playback_checked = false
  for i = 1, num_checkboxes do
    if playback_checkboxes[i].value then
      any_playback_checked = true
      break
    end
  end

  if any_playback_checked then
    -- Only write up to active_steps_playback
    for i = 1, active_steps_playback do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_playback) + 1
      
      -- Ensure the third effect column is visible
      if track.visible_effect_columns < 3 then
        track.visible_effect_columns = 4
      end

      if playback_checkboxes[checkbox_idx].value then
        line.effect_columns[3].number_string = "0B"
        line.effect_columns[3].amount_string = "00"
      else
        line.effect_columns[3].number_string = "0B"
        line.effect_columns[3].amount_string = "01"
      end
    end
    
    -- Replicate the playback pattern to the rest of the pattern
    for row = active_steps_playback + 1, pattern_length do
      local dest_line = pattern:track(track_index):line(row)
      local source_row = ((row - 1) % active_steps_playback) + 1
      local source_line = pattern:track(track_index):line(source_row)
      
      dest_line.effect_columns[3]:copy_from(source_line.effect_columns[3])
    end
  end
  
  initializing = false
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Received Playback Gater pattern")
end

-- Receive Panning checkboxes state
local function receive_panning_checkboxes()
  if not renoise.song() then return end

  initializing = true

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track
  local pattern_length = pattern.number_of_lines

  -- First, read the current pattern to set checkbox states
  for i = 1, num_checkboxes do
    local line = pattern:track(track_index):line(i)

    if panning_column_choice == "Panning Column" then
      renoise.song().selected_track.panning_column_visible = true
      if line:note_column(1).panning_string == "00" then
        panning_left_checkboxes[i].value = true
        panning_center_checkboxes[i].value = false
        panning_right_checkboxes[i].value = false
      elseif line:note_column(1).panning_string == "80" then
        panning_left_checkboxes[i].value = false
        panning_center_checkboxes[i].value = false
        panning_right_checkboxes[i].value = true
      elseif line:note_column(1).panning_string == "40" then
        panning_left_checkboxes[i].value = false
        panning_center_checkboxes[i].value = true
        panning_right_checkboxes[i].value = false
      end
    elseif panning_column_choice == "FX Column" then
      if line.effect_columns[4].number_string == "0P" then
        if line.effect_columns[4].amount_string == "00" then
          panning_left_checkboxes[i].value = true
          panning_center_checkboxes[i].value = false
          panning_right_checkboxes[i].value = false
        elseif line.effect_columns[4].amount_string == "FF" then
          panning_left_checkboxes[i].value = false
          panning_center_checkboxes[i].value = false
          panning_right_checkboxes[i].value = true
        elseif line.effect_columns[4].amount_string == "7F" then
          panning_left_checkboxes[i].value = false
          panning_center_checkboxes[i].value = true
          panning_right_checkboxes[i].value = false
        end
      end
    end
  end

  -- Now write the panning pattern based on checkboxes, but don't call insert_commands()
  -- Clear the panning columns first
  if panning_column_choice == "FX Column" then
    clear_effect_column_4()
  elseif panning_column_choice == "Panning Column" then
    -- Only clear if not used by retrig
    if retrig_column_choice ~= "Panning Column" then
      clear_panning_column()
    end
  end
  
  -- Write panning pattern based on checkboxes
  local all_panning_center = true
  for i = 1, num_checkboxes do
    if panning_left_checkboxes[i].value or panning_right_checkboxes[i].value then
      all_panning_center = false
      break
    end
  end

  if not all_panning_center then
    -- Only write up to active_steps_panning
    for i = 1, active_steps_panning do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_panning) + 1
      
      if panning_column_choice == "Panning Column" then
        renoise.song().selected_track.panning_column_visible = true
        if panning_left_checkboxes[checkbox_idx].value then
          line:note_column(1).panning_string = "00"
        elseif panning_right_checkboxes[checkbox_idx].value then
          line:note_column(1).panning_string = "80"
        else
          line:note_column(1).panning_string = "40"
        end
      elseif panning_column_choice == "FX Column" then
        if panning_left_checkboxes[checkbox_idx].value then
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "00"
        elseif panning_right_checkboxes[checkbox_idx].value then
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "FF"
        else
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "7F"
        end
      end
    end
    
    -- Replicate the panning pattern to the rest of the pattern
    for row = active_steps_panning + 1, pattern_length do
      local dest_line = pattern:track(track_index):line(row)
      local source_row = ((row - 1) % active_steps_panning) + 1
      local source_line = pattern:track(track_index):line(source_row)
      
      if panning_column_choice == "FX Column" then
        dest_line.effect_columns[4]:copy_from(source_line.effect_columns[4])
      elseif panning_column_choice == "Panning Column" then
        for col = 1, #source_line.note_columns do
          -- Only copy panning values, not retrig values
          if string.sub(source_line:note_column(col).panning_string, 1, 1) ~= "R" then
            dest_line:note_column(col).panning_string = source_line:note_column(col).panning_string
          end
        end
      end
    end
  end
  
  initializing = false
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Received Panning Gater pattern")
end

local function rand_volume_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while setting values
  for i = 1, num_checkboxes do
    checkboxes[i].value = (i <= active_steps_volume) and (math.random() > 0.5) or false
  end
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Randomize Retrig checkboxes
local function rand_retrig_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while setting values
  for i = 1, num_checkboxes do
    retrig_checkboxes[i].value = (i <= active_steps_retrig) and (math.random() > 0.5) or false
  end
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Randomize Playback checkboxes
local function rand_playback_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while setting values
  for i = 1, num_checkboxes do
    playback_checkboxes[i].value = (i <= active_steps_playback) and (math.random() > 0.5) or false
  end
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Randomize Panning checkboxes
local function rand_panning_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while setting values
  for i = 1, num_checkboxes do
    if i <= active_steps_panning then
      local rand_choice = math.random(1, 3)
      panning_left_checkboxes[i].value = (rand_choice == 1)
      panning_center_checkboxes[i].value = (rand_choice == 2)
      panning_right_checkboxes[i].value = (rand_choice == 3)
    else
      panning_left_checkboxes[i].value = false
      panning_center_checkboxes[i].value = true
      panning_right_checkboxes[i].value = false
    end
  end
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Clear Volume Gater
local function clear_volume_gater()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while clearing checkboxes
  -- Clear checkboxes
  for i = 1, num_checkboxes do
    checkboxes[i].value = false
  end
  
  -- Clear the actual pattern content
  if column_choice == "FX Column" or column_choice == "FX Column (L00)" then
    clear_effect_columns()
  elseif column_choice == "Volume Column" then
    clear_volume_column()
  end
  
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Clear Retrig checkboxes
local function clear_retrig_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while clearing checkboxes
  -- Clear checkboxes
  for i = 1, num_checkboxes do
    retrig_checkboxes[i].value = false
  end
  
  -- Clear the actual pattern content
  if retrig_column_choice == "FX Column" then
    clear_retrig()
  elseif retrig_column_choice == "Volume Column" then
    if column_choice ~= "Volume Column" then  -- Only if not used by volume gater
      clear_volume_column()
    end
  elseif retrig_column_choice == "Panning Column" then
    if panning_column_choice ~= "Panning Column" then  -- Only if not used by panning gater
      clear_panning_column()
    end
  end
  
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Clear Playback checkboxes
local function clear_playback_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while clearing checkboxes
  -- Clear checkboxes
  for i = 1, num_checkboxes do
    playback_checkboxes[i].value = false
  end
  
  -- Clear the actual pattern content
  clear_playback_effect()
  
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Clear Panning checkboxes
local function clear_panning_checkboxes()
  if not renoise.song() then return end

  initializing = true  -- Prevent updates while clearing checkboxes
  -- Clear checkboxes
  for i = 1, num_checkboxes do
    panning_left_checkboxes[i].value = false
    panning_center_checkboxes[i].value = true
    panning_right_checkboxes[i].value = false
  end
  
  -- Clear the actual pattern content
  if panning_column_choice == "FX Column" then
    clear_effect_column_4()
  elseif panning_column_choice == "Panning Column" then
    if retrig_column_choice ~= "Panning Column" then  -- Only if not used by retrig
      clear_panning_column()
    end
  end
  
  initializing = false
  insert_commands()  -- Single update at the end
end

-- Shift checkboxes left or right
local function shift_checkboxes(direction)
  if not renoise.song() then return end

  local shifted = {}
  if direction == "left" then
    for i = 1, num_checkboxes do
      shifted[i] = checkboxes[(i % num_checkboxes) + 1].value
    end
  elseif direction == "right" then
    for i = 1, num_checkboxes do
      shifted[i] = checkboxes[((i - 2) % num_checkboxes) + 1].value
    end
  end
  for i = 1, num_checkboxes do
    checkboxes[i].value = shifted[i] and i <= active_steps_volume
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

  if not initializing then
    insert_commands()
  end
end

-- Shift retrig checkboxes left or right
local function shift_retrig_checkboxes(direction)
  if not renoise.song() then return end

  local shifted = {}
  if direction == "left" then
    for i = 1, num_checkboxes do
      shifted[i] = retrig_checkboxes[(i % num_checkboxes) + 1].value
    end
  elseif direction == "right" then
    for i = 1, num_checkboxes do
      shifted[i] = retrig_checkboxes[((i - 2) % num_checkboxes) + 1].value
    end
  end
  for i = 1, num_checkboxes do
    retrig_checkboxes[i].value = shifted[i] and i <= active_steps_retrig
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

  if not initializing then
    insert_commands()
  end
end

-- Shift playback checkboxes left or right
local function shift_playback_checkboxes(direction)
  if not renoise.song() then return end

  local shifted = {}
  if direction == "left" then
    for i = 1, num_checkboxes do
      shifted[i] = playback_checkboxes[(i % num_checkboxes) + 1].value
    end
  elseif direction == "right" then
    for i = 1, num_checkboxes do
      shifted[i] = playback_checkboxes[((i - 2) % num_checkboxes) + 1].value
    end
  end
  for i = 1, num_checkboxes do
    playback_checkboxes[i].value = shifted[i] and i <= active_steps_playback
  end
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

  if not initializing then
    insert_commands()
  end
end

-- Shift panning checkboxes left or right
local function shift_panning_checkboxes(direction)
  if not renoise.song() then return end

  local shifted_left = {}
  local shifted_center = {}
  local shifted_right = {}

  if direction == "left" then
    for i = 1, num_checkboxes do
      shifted_left[i] = panning_left_checkboxes[(i % num_checkboxes) + 1].value
      shifted_center[i] = panning_center_checkboxes[(i % num_checkboxes) + 1].value
      shifted_right[i] = panning_right_checkboxes[(i % num_checkboxes) + 1].value
    end
  elseif direction == "right" then
    for i = 1, num_checkboxes do
      shifted_left[i] = panning_left_checkboxes[((i - 2) % num_checkboxes) + 1].value
      shifted_center[i] = panning_center_checkboxes[((i - 2) % num_checkboxes) + 1].value
      shifted_right[i] = panning_right_checkboxes[((i - 2) % num_checkboxes) + 1].value
    end
  end

  for i = 1, num_checkboxes do
    panning_left_checkboxes[i].value = shifted_left[i]
    panning_center_checkboxes[i].value = shifted_center[i]
    panning_right_checkboxes[i].value = shifted_right[i]
  end

  if not initializing then
    insert_commands()
  end
end

-- Clear Effect Columns
function clear_effect_columns()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    for j = 1, #line.effect_columns do
      if line.effect_columns[j].number_string == "0C" or line.effect_columns[j].number_string == "0L" then
        line.effect_columns[j].number_string = ""
        line.effect_columns[j].amount_string = ""
      end
    end
  end
  renoise.app():show_status("Cleared FX Column")
end

-- Add this at the top of the file with other globals
local suppress_status_messages = false

-- Modify the clear_retrig function to respect the suppress flag
function clear_retrig()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    line.effect_columns[2].number_string = ""
    line.effect_columns[2].amount_string = ""
  end
  
  if not suppress_status_messages then
    renoise.app():show_status("Cleared Retrig Effect")
  end
end

-- Similarly modify other clear functions to respect the suppress flag
function clear_volume_column()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    for j = 1, track.visible_note_columns do
      line:note_column(j).volume_string = ""
    end
  end
  
  if not suppress_status_messages then
    renoise.app():show_status("Cleared Volume Column")
  end
end

function clear_panning_column()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index
  local track = renoise.song().selected_track

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    for j = 1, track.visible_note_columns do
      line:note_column(j).panning_string = ""
    end
  end
  
  if not suppress_status_messages then
    renoise.app():show_status("Cleared Panning Column")
  end
end


-- Clear Playback Effect
function clear_playback_effect()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    line.effect_columns[3].number_string = ""
    line.effect_columns[3].amount_string = ""
  end
  
  if not suppress_status_messages then
    renoise.app():show_status("Cleared Playback Effect")
  end
end

-- Clear Effect Column 4
function clear_effect_column_4()
  if not renoise.song() then return end

  local pattern = renoise.song().selected_pattern
  local track_index = renoise.song().selected_track_index

  for i = 1, max_rows do
    local line = pattern:track(track_index):line(i)
    if line.effect_columns[4] then
      if line.effect_columns[4].number_string == "0P" then
        line.effect_columns[4].number_string = ""
        line.effect_columns[4].amount_string = ""
      end
    end
  end
  renoise.app():show_status("Cleared Effect Column 4")
end

-- Now modify the insert_commands function to be more efficient
function insert_commands()
  max_rows = renoise.song().selected_pattern.number_of_lines

  if not renoise.song() then return end

  -- Suppress status messages during batch operations
  suppress_status_messages = true
  
  local pattern = renoise.song().selected_pattern
  local track = renoise.song().selected_track
  local track_index = renoise.song().selected_track_index
  local visible_note_columns = track.visible_note_columns

  -- IMPORTANT: Only clear retrig columns if we're actually writing to them
  local retrig_is_empty = true
  for i = 1, num_checkboxes do
    if retrig_checkboxes[i].value then
      retrig_is_empty = false
      break
    end
  end
  
  -- Only clear retrig columns if we're actually writing retrig values
  if not retrig_is_empty then
    if retrig_column_choice == "FX Column" then
      clear_retrig()
    elseif retrig_column_choice == "Volume Column" then
      -- Only clear if not used by volume gater
      if column_choice ~= "Volume Column" then
        clear_volume_column()
      end
    elseif retrig_column_choice == "Panning Column" then
      -- Only clear if not used by panning gater
      if panning_column_choice ~= "Panning Column" then
        clear_panning_column()
      end
    end
  end

  -- Ensure effect columns are visible
  if track.visible_effect_columns < 4 then
    track.visible_effect_columns = 4
  end

  -- Volume handling
  local any_checkbox_checked = false
  for i = 1, num_checkboxes do
    if checkboxes[i].value then
      any_checkbox_checked = true
      break
    end
  end

  if any_checkbox_checked then
    -- Only write up to active_steps_volume
    for i = 1, active_steps_volume do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_volume) + 1
      
      if column_choice == "FX Column" then
        if checkboxes[checkbox_idx].value then
          line.effect_columns[1].number_string = "0C"
          line.effect_columns[1].amount_string = "0F"
        else
          line.effect_columns[1].number_string = "0C"
          line.effect_columns[1].amount_string = "00"
        end
      elseif column_choice == "Volume Column" then
        track.volume_column_visible = true
        for j = 1, visible_note_columns do
          local note_column = line:note_column(j)
          if checkboxes[checkbox_idx].value then
            note_column.volume_string = "80"
          else
            note_column.volume_string = "00"
          end
        end
      elseif column_choice == "FX Column (L00)" then
        if checkboxes[checkbox_idx].value then
          line.effect_columns[1].number_string = "0L"
          line.effect_columns[1].amount_string = "C0"
        else
          line.effect_columns[1].number_string = "0L"
          line.effect_columns[1].amount_string = "00"
        end
      end
    end
  end

  -- Panning handling
  local all_panning_center = true
  for i = 1, num_checkboxes do
    if panning_left_checkboxes[i].value or panning_right_checkboxes[i].value then
      all_panning_center = false
      break
    end
  end

  if not all_panning_center then
    -- Only write up to active_steps_panning
    for i = 1, active_steps_panning do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_panning) + 1
      
      if panning_column_choice == "Panning Column" then
        renoise.song().selected_track.panning_column_visible = true
        if panning_left_checkboxes[checkbox_idx].value then
          line:note_column(1).panning_string = "00"
        elseif panning_right_checkboxes[checkbox_idx].value then
          line:note_column(1).panning_string = "80"
        else
          line:note_column(1).panning_string = "40"
        end
      elseif panning_column_choice == "FX Column" then
        if panning_left_checkboxes[checkbox_idx].value then
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "00"
        elseif panning_right_checkboxes[checkbox_idx].value then
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "FF"
        else
          line.effect_columns[4].number_string = "0P"
          line.effect_columns[4].amount_string = "7F"
        end
      end
    end
  end

  -- Retrig handling - only write if we have retrig values
  if not retrig_is_empty then
    -- Only write up to active_steps_retrig
    for i = 1, active_steps_retrig do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_retrig) + 1

      if retrig_checkboxes[checkbox_idx].value then
        if retrig_column_choice == "FX Column" then
          line.effect_columns[2].number_string = "0R"
          line.effect_columns[2].amount_string = string.format("%02X", retrig_value)
        elseif retrig_column_choice == "Volume Column" then
          track.volume_column_visible = true
          for j = 1, visible_note_columns do
            local note_column = line:note_column(j)
            note_column.volume_string = string.format("R%X", retrig_value)
          end
        elseif retrig_column_choice == "Panning Column" then
          renoise.song().selected_track.panning_column_visible = true
          for j = 1, visible_note_columns do
            local note_column = line:note_column(j)
            note_column.panning_string = string.format("R%X", retrig_value)
          end
        end
      end
    end
  end

  -- Playback handling
  local any_playback_checked = false
  for i = 1, num_checkboxes do
    if playback_checkboxes[i].value then
      any_playback_checked = true
      break
    end
  end

  if any_playback_checked then
    -- Only write up to active_steps_playback
    for i = 1, active_steps_playback do
      local line = pattern:track(track_index):line(i)
      -- Get the actual checkbox index, looping if needed
      local checkbox_idx = ((i - 1) % active_steps_playback) + 1
      
      -- Ensure the third effect column is visible
      if track.visible_effect_columns < 3 then
        track.visible_effect_columns = 4
      end

      if playback_checkboxes[checkbox_idx].value then
        line.effect_columns[3].number_string = "0B"
        line.effect_columns[3].amount_string = "00"
      else
        line.effect_columns[3].number_string = "0B"
        line.effect_columns[3].amount_string = "01"
      end
    end
  end

  -- After writing the pattern based on active steps, replicate to fill the rest
  PakettiReplicateAtCursorGater(0, "selected_track", "above_and_current")

  -- Re-enable status messages and show a single message
  suppress_status_messages = false
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  renoise.app():show_status("Gater pattern updated")
end

function PakettiReplicateAtCursorGater(transpose, tracks_option, row_option)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  
  -- Function to replicate content on a track
  local function replicate_on_track(track_index)
    -- IMPORTANT: We'll handle each effect type completely independently
    
    -- 1. Volume effects replication
    if active_steps_volume > 0 then
      
      -- Clear the rest of the pattern first to avoid interference
      for row = active_steps_volume + 1, pattern_length do
        local line = pattern:track(track_index):line(row)
        if column_choice == "FX Column" or column_choice == "FX Column (L00)" then
          line.effect_columns[1].number_string = ""
          line.effect_columns[1].amount_string = ""
        elseif column_choice == "Volume Column" then
          for col = 1, #line.note_columns do
            line:note_column(col).volume_string = ""
          end
        end
      end
      
      -- Now replicate the pattern
      for row = active_steps_volume + 1, pattern_length do
        local dest_line = pattern:track(track_index):line(row)
        local source_row = ((row - 1) % active_steps_volume) + 1
        local source_line = pattern:track(track_index):line(source_row)
        
        if column_choice == "FX Column" or column_choice == "FX Column (L00)" then
          dest_line.effect_columns[1]:copy_from(source_line.effect_columns[1])
        elseif column_choice == "Volume Column" then
          for col = 1, #source_line.note_columns do
            dest_line.note_columns[col].volume_string = source_line.note_columns[col].volume_string
          end
        end
      end
    end
    
    -- 2. Retrig effects replication
    if active_steps_retrig > 0 then
      
      -- Clear the rest of the pattern first
      for row = active_steps_retrig + 1, pattern_length do
        local line = pattern:track(track_index):line(row)
        if retrig_column_choice == "FX Column" then
          line.effect_columns[2].number_string = ""
          line.effect_columns[2].amount_string = ""
        elseif retrig_column_choice == "Volume Column" then
          -- Don't clear if we're also using volume column for volume gater
          if column_choice ~= "Volume Column" then
            for col = 1, #line.note_columns do
              line:note_column(col).volume_string = ""
            end
          end
        elseif retrig_column_choice == "Panning Column" then
          -- Don't clear if we're also using panning column for panning gater
          if panning_column_choice ~= "Panning Column" then
            for col = 1, #line.note_columns do
              line:note_column(col).panning_string = ""
            end
          end
        end
      end
      
      -- Now replicate the pattern
      for row = active_steps_retrig + 1, pattern_length do
        local dest_line = pattern:track(track_index):line(row)
        local source_row = ((row - 1) % active_steps_retrig) + 1
        local source_line = pattern:track(track_index):line(source_row)
        
        if retrig_column_choice == "FX Column" then
          dest_line.effect_columns[2]:copy_from(source_line.effect_columns[2])
        elseif retrig_column_choice == "Volume Column" then
          for col = 1, #source_line.note_columns do
            if string.sub(source_line.note_columns[col].volume_string, 1, 1) == "R" then
              dest_line.note_columns[col].volume_string = source_line.note_columns[col].volume_string
            end
          end
        elseif retrig_column_choice == "Panning Column" then
          for col = 1, #source_line.note_columns do
            if string.sub(source_line.note_columns[col].panning_string, 1, 1) == "R" then
              dest_line.note_columns[col].panning_string = source_line.note_columns[col].panning_string
            end
          end
        end
      end
    end
    
    -- 3. Playback effects replication
    if active_steps_playback > 0 then
      
      -- Clear the rest of the pattern first
      for row = active_steps_playback + 1, pattern_length do
        local line = pattern:track(track_index):line(row)
        line.effect_columns[3].number_string = ""
        line.effect_columns[3].amount_string = ""
      end
      
      -- Now replicate the pattern
      for row = active_steps_playback + 1, pattern_length do
        local dest_line = pattern:track(track_index):line(row)
        local source_row = ((row - 1) % active_steps_playback) + 1
        local source_line = pattern:track(track_index):line(source_row)
        
        dest_line.effect_columns[3]:copy_from(source_line.effect_columns[3])
      end
    end
    
    -- 4. Panning effects replication
    if active_steps_panning > 0 then
      
      -- Clear the rest of the pattern first
      for row = active_steps_panning + 1, pattern_length do
        local line = pattern:track(track_index):line(row)
        if panning_column_choice == "FX Column" then
          line.effect_columns[4].number_string = ""
          line.effect_columns[4].amount_string = ""
        elseif panning_column_choice == "Panning Column" then
          -- Don't clear if we're also using panning column for retrig
          if retrig_column_choice ~= "Panning Column" then
            for col = 1, #line.note_columns do
              line:note_column(col).panning_string = ""
            end
          end
        end
      end
      
      -- Now replicate the pattern
      for row = active_steps_panning + 1, pattern_length do
        local dest_line = pattern:track(track_index):line(row)
        local source_row = ((row - 1) % active_steps_panning) + 1
        local source_line = pattern:track(track_index):line(source_row)
        
        if panning_column_choice == "FX Column" then
          dest_line.effect_columns[4]:copy_from(source_line.effect_columns[4])
        elseif panning_column_choice == "Panning Column" then
          for col = 1, #source_line.note_columns do
            -- Only copy panning values, not retrig values
            if string.sub(source_line.note_columns[col].panning_string, 1, 1) ~= "R" then
              dest_line.note_columns[col].panning_string = source_line.note_columns[col].panning_string
            end
          end
        end
      end
    end
  end

  if tracks_option == "all_tracks" then
    for track_index = 1, #pattern.tracks do
      replicate_on_track(track_index)
    end
  elseif tracks_option == "selected_track" then
    local selected_track_index = song.selected_track_index
    replicate_on_track(selected_track_index)
  else
    renoise.app():show_status("Invalid tracks option: " .. tostring(tracks_option))
    return
  end

  renoise.app():show_status("Replicated all Gater patterns")
end





-- Preset functionality
local function apply_preset(preset, is_retrig, is_playback)
  if not renoise.song() then return end

  initializing = true

  local preset_state = {}
  if preset == "all" then
    preset_state = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
  elseif preset == "every_2nd" then
    preset_state = {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0}
  elseif preset == "every_third" then
    preset_state = {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1}
  elseif preset == "every_fourth" then
    preset_state = {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0}
  elseif preset == "jaguar" then
    preset_state = {1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0}
  elseif preset == "caapi" then
    preset_state = {1,0,1,0,1,0,1,0,1,1,1,0,1,1,1,0}
  elseif preset == "none" then
    preset_state = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
  end

  if is_retrig then
    for i = 1, num_checkboxes do
      retrig_checkboxes[i].value = preset_state[i] == 1
    end
  elseif is_playback then
    for i = 1, num_checkboxes do
      playback_checkboxes[i].value = preset_state[i] == 1
    end
  else
    for i = 1, num_checkboxes do
      checkboxes[i].value = preset_state[i] == 1
    end
  end

  initializing = false
  insert_commands()
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Custom key handler function
local function my_keyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    dialog = nil
    return
  else 
    return key
  end
end

-- Create the dialog
function pakettiGaterDialog()
    if dialog and dialog.visible then
      -- Add cleanup code here before closing
      if track_notifier and renoise.song().selected_track_index_observable:has_notifier(track_notifier) then
        renoise.song().selected_track_index_observable:remove_notifier(track_notifier)
      end
      dialog:close()
      dialog = nil
      return
    end
  initializing = true -- Start initialization

  initialize_checkboxes(num_checkboxes)
  local content = vb:column {
    vb:text { text = "Volume Gater", font = "bold", style="strong" },
    vb:switch {
      items = { "FX Column (C00)", "Volume Column", "FX Column (L00)" },
      value = 1,
      width = 300,
      notifier = function(index)
        column_choice = (index == 1) and "FX Column" or (index == 2) and "Volume Column" or "FX Column (L00)"
        if not initializing then
          insert_commands()
        end
      end
    },
    vb:row {
      buttons[1], buttons[2], buttons[3], buttons[4], buttons[5], buttons[6], buttons[7], buttons[8],
      buttons[9], buttons[10], buttons[11], buttons[12], buttons[13], buttons[14], buttons[15], buttons[16],
      vb:valuebox {
        min = 1,
        max = num_checkboxes,
        value = active_steps_volume,
        width = 50,
        notifier = function(value)
          set_active_steps_volume(value)
        end
      }
    },
    vb:row(checkboxes),
    vb:row {
      vb:button { text = "Clear", pressed = clear_volume_gater },
      vb:button { text = "Random", pressed = rand_volume_checkboxes },
      vb:button { text = "<", pressed = function() 
        initializing = true
        shift_checkboxes("left")
        initializing = false
        insert_commands()
      end },
      vb:button { text = ">", pressed = function() 
        initializing = true
        shift_checkboxes("right")
        initializing = false
        insert_commands()
      end },
      vb:button { text = "Clear FX Column", pressed = clear_effect_columns },
      vb:button { text = "Clear Volume Column", pressed = clear_volume_column },
      vb:button { text = "Receive", pressed = receive_volume_checkboxes }
    },
    vb:row {
      vb:button { text = "All", pressed = function() apply_preset("all", false, false) end },
      vb:button { text = "Every 2nd", pressed = function() apply_preset("every_2nd", false, false) end },
      vb:button { text = "Every 3rd", pressed = function() apply_preset("every_third", false, false) end },
      vb:button { text = "Every 4th", pressed = function() apply_preset("every_fourth", false, false) end },
      vb:button { text = "Jaguar", pressed = function() apply_preset("jaguar", false, false) end},
      vb:button { text = "Caapi", pressed = function() apply_preset("caapi", false, false) end} 
    },
    vb:text { text = "Retrig Gater", font = "bold", style="strong"},
    vb:row {
      vb:valuebox {
        min = 1,
        max = 15,
        value = retrig_value,
        width = 50,
        tooltip = "Retrig Speed",
        notifier = function(value)
          retrig_value = value
          if not initializing then
            insert_commands()
          end
        end
      },
      vb:text { text = "Retrig Speed" }
    },
    vb:switch {
      items = { "FX Column", "Volume Column", "Panning Column" },
      value = 1,
      width = 300,
      notifier = function(index)
        retrig_column_choice = (index == 1) and "FX Column" or (index == 2) and "Volume Column" or "Panning Column"
        if not initializing then
          insert_commands()
        end
      end
    },
    vb:row {
      retrig_buttons[1], retrig_buttons[2], retrig_buttons[3], retrig_buttons[4], retrig_buttons[5], retrig_buttons[6], retrig_buttons[7], retrig_buttons[8],
      retrig_buttons[9], retrig_buttons[10], retrig_buttons[11], retrig_buttons[12], retrig_buttons[13], retrig_buttons[14], retrig_buttons[15], retrig_buttons[16],
      vb:valuebox {
        min = 1,
        max = num_checkboxes,
        value = active_steps_retrig,
        width = 50,
        notifier = set_active_steps_retrig
      }
    },
    vb:row(retrig_checkboxes),
    vb:row {
      vb:button { text = "Clear", pressed = clear_retrig_checkboxes },
      vb:button { text = "Random", pressed = rand_retrig_checkboxes },
      vb:button { text = "<", pressed = function() 
        initializing = true
        shift_retrig_checkboxes("left")
        initializing = false
        insert_commands()
      end },
      vb:button { text = ">", pressed = function() 
        initializing = true
        shift_retrig_checkboxes("right")
        initializing = false
        insert_commands()
      end },
            vb:button { text = "Receive", pressed = receive_retrig_checkboxes }
    },
    vb:text { text = "Playback Direction Gater", font = "bold", style="strong" },
    vb:row {
      playback_buttons[1], playback_buttons[2], playback_buttons[3], playback_buttons[4], playback_buttons[5], playback_buttons[6], playback_buttons[7], playback_buttons[8],
      playback_buttons[9], playback_buttons[10], playback_buttons[11], playback_buttons[12], playback_buttons[13], playback_buttons[14], playback_buttons[15], playback_buttons[16],
      vb:valuebox {
        min = 1,
        max = num_checkboxes,
        value = active_steps_playback,
        width = 50,
        notifier = set_active_steps_playback
      }
    },
    vb:row(playback_checkboxes),
    vb:row {
      vb:button { text = "Clear", pressed = clear_playback_checkboxes },
      vb:button { text = "Random", pressed = rand_playback_checkboxes },
      vb:button { text = "<", pressed = function() 
        initializing = true
        shift_playback_checkboxes("left")
        initializing = false
        insert_commands()
      end },
      vb:button { text = ">", pressed = function() 
        initializing = true
        shift_playback_checkboxes("right")
        initializing = false
        insert_commands()
      end },
            vb:button { text = "Receive", pressed = receive_playback_checkboxes }
    },
    vb:text { text = "Panning Gater", font = "bold", style="strong" },
    vb:switch {
      items = { "FX Column", "Panning Column" },
      value = 1,
      width = 300,
      notifier = function(index)
        panning_column_choice = (index == 1) and "FX Column" or "Panning Column"
        if not initializing then
          insert_commands()
        end
      end
    },
    vb:row {
      panning_buttons[1], panning_buttons[2], panning_buttons[3], panning_buttons[4], panning_buttons[5], 
      panning_buttons[6], panning_buttons[7], panning_buttons[8], panning_buttons[9], 
      panning_buttons[10], panning_buttons[11], panning_buttons[12], panning_buttons[13], 
      panning_buttons[14], panning_buttons[15], panning_buttons[16],
      vb:valuebox {
        min = 1,
        max = num_checkboxes,
        value = active_steps_panning,
        width = 50,
        notifier = set_active_steps_panning
      }
    },
    vb:row(panning_left_checkboxes),
    vb:row(panning_center_checkboxes),
    vb:row(panning_right_checkboxes),
    vb:row {
      vb:button { text = "Clear", pressed = clear_panning_checkboxes },
      vb:button { text = "Random", pressed = rand_panning_checkboxes },
      vb:button { text = "<", pressed = function() 
        initializing = true
        shift_panning_checkboxes("left")
        initializing = false
        insert_commands()
      end },
      vb:button { text = ">", pressed = function() 
        initializing = true
        shift_panning_checkboxes("right")
        initializing = false
        insert_commands()
      end },
            vb:button { text = "Receive", pressed = receive_panning_checkboxes },
    },
    vb:row {
      vb:text{text="Global", font="bold", style="strong"},
      vb:checkbox {
        value = auto_grab,
        notifier = function(value)
          auto_grab = value
          if value then
            previous_track_index = renoise.song().selected_track_index
            -- Remove existing notifier if it exists
            if track_notifier and renoise.song().selected_track_index_observable:has_notifier(track_notifier) then
              renoise.song().selected_track_index_observable:remove_notifier(track_notifier)
            end
            -- Add new notifier
            track_notifier = auto_grab_handler
            renoise.song().selected_track_index_observable:add_notifier(track_notifier)
          else
            -- Remove notifier when auto-grab is disabled
            if track_notifier and renoise.song().selected_track_index_observable:has_notifier(track_notifier) then
              renoise.song().selected_track_index_observable:remove_notifier(track_notifier)
            end
          end
        end
      },
      vb:text { text = "Auto-Grab", style="strong", font="bold" },
    
      
      vb:button { text = "<<", pressed = function()
        initializing = true  -- Prevent multiple updates
        shift_checkboxes("left")
        shift_retrig_checkboxes("left")
        shift_playback_checkboxes("left")
        shift_panning_checkboxes("left")
        initializing = false
        insert_commands()  -- Single update at the end
      end },
      vb:button { text = ">>", pressed = function()
        initializing = true  -- Prevent multiple updates
        shift_checkboxes("right")
        shift_retrig_checkboxes("right")
        shift_playback_checkboxes("right")
        shift_panning_checkboxes("right")
        initializing = false
        insert_commands()  -- Single update at the end
      end },
      vb:button { text = "Global Clear", pressed = function()
        initializing = true
        -- Clear volume
        for i = 1, num_checkboxes do
          checkboxes[i].value = false
        end
        -- Clear retrig
        for i = 1, num_checkboxes do
          retrig_checkboxes[i].value = false
        end
        -- Clear playback
        for i = 1, num_checkboxes do
          playback_checkboxes[i].value = false
        end
        -- Clear panning (set all to center)
        for i = 1, num_checkboxes do
          panning_left_checkboxes[i].value = false
          panning_center_checkboxes[i].value = true
          panning_right_checkboxes[i].value = false
        end

        -- Clear all pattern content
        suppress_status_messages = true  -- Prevent multiple status messages
        
        -- Clear volume content based on column choice
        if column_choice == "FX Column" or column_choice == "FX Column (L00)" then
          clear_effect_columns()
        elseif column_choice == "Volume Column" then
          clear_volume_column()
        end
        
        -- Clear retrig content based on column choice
        if retrig_column_choice == "FX Column" then
          clear_retrig()
        elseif retrig_column_choice == "Volume Column" then
          if column_choice ~= "Volume Column" then  -- Only if not used by volume gater
            clear_volume_column()
          end
        elseif retrig_column_choice == "Panning Column" then
          if panning_column_choice ~= "Panning Column" then  -- Only if not used by panning gater
            clear_panning_column()
          end
        end
        
        -- Clear playback content
        clear_playback_effect()
        
        -- Clear panning content based on column choice
        if panning_column_choice == "FX Column" then
          clear_effect_column_4()
        elseif panning_column_choice == "Panning Column" then
          if retrig_column_choice ~= "Panning Column" then  -- Only if not used by retrig
            clear_panning_column()
          end
        end

        suppress_status_messages = false
        initializing = false
        insert_commands()  -- Single update at the end
      end },

      vb:button { text = "Global Random", pressed = function()
        initializing = true
        -- Randomize volume
        for i = 1, num_checkboxes do
          if i <= active_steps_volume then
            checkboxes[i].value = math.random() > 0.5
          else
            checkboxes[i].value = false
          end
        end
        -- Randomize retrig
        for i = 1, num_checkboxes do
          if i <= active_steps_retrig then
            retrig_checkboxes[i].value = math.random() > 0.5
          else
            retrig_checkboxes[i].value = false
          end
        end
        -- Randomize playback
        for i = 1, num_checkboxes do
          if i <= active_steps_playback then
            playback_checkboxes[i].value = math.random() > 0.5
          else
            playback_checkboxes[i].value = false
          end
        end
        -- Randomize panning
        for i = 1, num_checkboxes do
          if i <= active_steps_panning then
            local rand_choice = math.random(1, 3)
            if rand_choice == 1 then
              panning_left_checkboxes[i].value = true
              panning_center_checkboxes[i].value = false
              panning_right_checkboxes[i].value = false
            elseif rand_choice == 2 then
              panning_left_checkboxes[i].value = false
              panning_center_checkboxes[i].value = true
              panning_right_checkboxes[i].value = false
            else
              panning_left_checkboxes[i].value = false
              panning_center_checkboxes[i].value = false
              panning_right_checkboxes[i].value = true
            end
          else
            panning_left_checkboxes[i].value = false
            panning_center_checkboxes[i].value = true
            panning_right_checkboxes[i].value = false
          end
        end
        initializing = false
        insert_commands()  -- Single update at the end
      end },

        vb:button { text = "Global Receive", pressed = function()
        initializing = true
        receive_volume_checkboxes()
        receive_retrig_checkboxes()
        receive_playback_checkboxes()
        receive_panning_checkboxes()
        initializing = false
        insert_commands()
      end }
    }
  }

  dialog = renoise.app():show_custom_dialog("Paketti Volume/Retrig/Playback/Panning Gater", content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

  -- Automatically receive the current pattern state when opening the dialog
  receive_volume_checkboxes()
  receive_retrig_checkboxes()
  receive_playback_checkboxes()
  receive_panning_checkboxes()
  
  initializing = false -- End initialization
end

-- Handle scenario when the dialog is closed by other means
renoise.app().window.active_middle_frame_observable:add_notifier(function()
  if dialog and not dialog.visible then
    dialog = nil
  end
end)

-- Keybinding function
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Gater Dialog...",invoke=function()
  if dialog and dialog.visible then
    -- Add cleanup code here before closing
    if track_notifier and renoise.song().selected_track_index_observable:has_notifier(track_notifier) then
      renoise.song().selected_track_index_observable:remove_notifier(track_notifier)
    end
    dialog:close()
    dialog = nil
    return
  end
  
  max_rows = renoise.song().selected_pattern.number_of_lines
  if renoise.song() then
    pakettiGaterDialog()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end}





-- Add this new function
function auto_grab_handler()
  if not auto_grab then return end
  
  local current_track_index = renoise.song().selected_track_index
  if current_track_index ~= previous_track_index then
    previous_track_index = current_track_index
    initializing = true
    receive_volume_checkboxes()
    receive_retrig_checkboxes()
    receive_playback_checkboxes()
    receive_panning_checkboxes()
    initializing = false
    insert_commands()
  end
end
