local vb = renoise.ViewBuilder()
local dialog = nil

local set_to_selected_instrument = preferences.OctaMEDPickPutSlots.SetSelectedInstrument.value or false
local use_edit_step_for_put = preferences.OctaMEDPickPutSlots.UseEditStep.value or false
local randomize_enabled = preferences.OctaMEDPickPutSlots.RandomizeEnabled.value or false
local randomize_percentage = preferences.OctaMEDPickPutSlots.RandomizePercentage.value or 100

-- Function to update the textfield display for empty slots
local function check_and_update_slot_display(slot_index)
  local textfield_value = vb.views["slot_display_"..string.format("%02d", slot_index)].text
  -- If the textfield only contains ' || ' or is empty, set it to "Slot is Empty"
  if textfield_value == " || " or textfield_value == "" then
    vb.views["slot_display_"..string.format("%02d", slot_index)].text = "Slot " .. string.format("%02d", slot_index) .. ": Empty"
  end
end

-- Function to save the picked slot data to preferences
local function save_slot_to_preferences(slot_index)
  local slot_key = "Slot" .. string.format("%02d", slot_index)
  local slot_text = vb.views["slot_display_"..string.format("%02d", slot_index)].text

  -- Ensure slot data is properly saved if the slot is not empty
  if slot_text ~= "Slot " .. string.format("%02d", slot_index) .. ": Empty" and slot_text ~= "" then
    print("Saving Slot", slot_index, "to preferences:", slot_text)
    preferences.OctaMEDPickPutSlots[slot_key].value = slot_text
  end

  -- Save the preferences document
  renoise.tool().preferences:save_as("preferences.xml")
end

-- Helper function to split a string by a given delimiter
local function string_split(input_str, delimiter)
  local result = {}
  for match in (input_str .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

-- Function to save checkbox preferences
local function save_checkbox_preference()
  preferences.OctaMEDPickPutSlots.SetSelectedInstrument.value = set_to_selected_instrument
  preferences.OctaMEDPickPutSlots.UseEditStep.value = use_edit_step_for_put
  preferences.OctaMEDPickPutSlots.RandomizeEnabled.value = randomize_enabled
  preferences.OctaMEDPickPutSlots.RandomizePercentage.value = randomize_percentage
  renoise.tool().preferences:save_as("preferences.xml")
end

-- Call this function after loading from preferences
local function load_slots_from_preferences()
  for i = 1, 10 do
    local slot_key = "Slot" .. string.format("%02d", i)
    local saved_slot_data = preferences.OctaMEDPickPutSlots[slot_key].value

    if saved_slot_data ~= "" then
      print("Loading Slot", i, "from preferences:", saved_slot_data)
      vb.views["slot_display_"..string.format("%02d", i)].text = saved_slot_data

      -- Check and update the slot display after loading data
      check_and_update_slot_display(i)
    end
  end
end

local function clear_pick(slot_index)
  -- Reset the slot text in preferences
  local slot_key = "Slot" .. string.format("%02d", slot_index)
  preferences.OctaMEDPickPutSlots[slot_key].value = "Slot " .. string.format("%02d", slot_index) .. ": Empty"
  renoise.tool().preferences:save_as("preferences.xml")

  -- Reset the textfield to empty state if the dialog is open
  if vb and vb.views["slot_display_"..string.format("%02d", slot_index)] then
    vb.views["slot_display_"..string.format("%02d", slot_index)].text = "Slot " .. string.format("%02d", slot_index) .. ": Empty"
  end

  -- Update status message
  renoise.app():show_status("Cleared Pick Slot " .. slot_index)
end

-- Function to handle the Put operation for Effect Columns
local function put_effect_columns(effect_data, line_indices)
  local track = renoise.song().selected_track

  -- Ensure the track has effect columns
  if track.visible_effect_columns == 0 then
    renoise.app():show_status("This track does not have visible effect columns.")
    return
  end

  -- Update the number of visible effect columns only if the pick-slot has more columns
  local effect_count_in_pick_slot = #effect_data
  if effect_count_in_pick_slot > track.visible_effect_columns then
    track.visible_effect_columns = effect_count_in_pick_slot
  end

  -- Iterate over the specified lines
  for _, line_index in ipairs(line_indices) do
    local pattern_line = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[line_index]

    -- Write data into the visible effect columns without reducing the number of columns
    for i = 1, math.min(effect_count_in_pick_slot, track.visible_effect_columns) do
      local effect_column = pattern_line.effect_columns[i]
      local effect_str = effect_data[i]

      -- Handle the effect command and value properly
      effect_column.number_string = effect_str:sub(1, 2) -- First two characters (effect number)
      effect_column.amount_string = effect_str:sub(3, 4) -- Last two characters (effect amount)
    end
  end

  renoise.app():show_status("Effect columns updated successfully")
end

local function put_note_instrument(slot_index)
  local track = renoise.song().selected_track
  local pattern = renoise.song().selected_pattern
  local current_line_index = renoise.song().selected_line_index
  local selection = renoise.song().selection_in_pattern

  local textfield_value = vb.views["slot_display_"..string.format("%02d", slot_index)].text
  if textfield_value == "Slot " .. string.format("%02d", slot_index) .. ": Empty" then
    renoise.app():show_status("Slot " .. string.format("%02d", slot_index) .. " is empty.")
    return
  end

  -- Split the text into note data and effect data
  local parts = string_split(textfield_value, "||")
  local note_data = string_split(parts[1] or "", "|")
  local effect_data = string_split(parts[2] or "", "|")

  local process_note_columns = true
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    process_note_columns = false
  end

  -- If there are no note columns in the slot data, do not overwrite current note columns
  if not note_data or #note_data == 0 or note_data[1]:match("^%s*$") then
    process_note_columns = false
  end

  -- Determine the lines to process based on selection, randomization and edit step
  local line_indices = {}
  local pattern_length = pattern.number_of_lines
  local edit_step = renoise.song().transport.edit_step

  if selection then
    -- Process selection range with edit step if enabled
    local step = (use_edit_step_for_put and edit_step > 0) and edit_step or 1
    for line_index = selection.start_line, selection.end_line, step do
      if randomize_enabled then
        if math.random(100) <= randomize_percentage then
          table.insert(line_indices, line_index)
        end
      else
        table.insert(line_indices, line_index)
      end
    end
  else
    -- Process single line
    if use_edit_step_for_put and edit_step > 0 then
      table.insert(line_indices, current_line_index)
      renoise.song().selected_line_index = math.min(current_line_index + edit_step, pattern_length)
    else
      table.insert(line_indices, current_line_index)
    end
  end

  for _, line_index in ipairs(line_indices) do
    local pattern_line = pattern.tracks[renoise.song().selected_track_index].lines[line_index]

    -- Process Note Columns if applicable
    if process_note_columns then
      -- Update the number of visible note columns to fit the picked data
      if #note_data > track.visible_note_columns then
        track.visible_note_columns = #note_data
      end

      -- Process and write to all note columns
      for i = 1, math.min(#note_data, track.visible_note_columns) do
        local note_column = pattern_line.note_columns[i]
        local note_parts = string_split(note_data[i]:gsub("^%s+", ""), " ")  -- Remove leading spaces

        -- Assign the note column values only if they are not empty
        if note_parts[1] ~= "---" and note_parts[1] ~= "..." then
          note_column.note_string = note_parts[1]
        end

        if note_parts[2] ~= ".." then
          if set_to_selected_instrument then
            note_column.instrument_value = renoise.song().selected_instrument_index - 1
          else
            note_column.instrument_string = note_parts[2]
          end
        end

        if note_parts[3] ~= ".." then
          renoise.song().selected_track.volume_column_visible = true
          note_column.volume_string = note_parts[3]
        end

        if note_parts[4] ~= ".." then
          renoise.song().selected_track.panning_column_visible = true
          note_column.panning_string = note_parts[4]
        end

        if note_parts[5] ~= ".." then
          renoise.song().selected_track.delay_column_visible = true
          note_column.delay_string = note_parts[5]
        end

        -- Handle samplefx data
        if #note_parts > 5 and note_parts[6] ~= "...." then
          renoise.song().selected_track.sample_effects_column_visible = true
          note_column.effect_number_string = note_parts[6]:sub(1, 2) -- Effect command
          note_column.effect_amount_string = note_parts[6]:sub(3, 4) -- Effect value
        end
      end
    end

    -- After processing note columns, call put_effect_columns for effect data
    if effect_data and #effect_data > 0 and effect_data[1] ~= "" then
      put_effect_columns(effect_data, {line_index})
    end
  end

  -- Update status and return focus to pattern editor
  renoise.app():show_status("Put: Slot " .. string.format("%02d", slot_index) .. " - " .. textfield_value)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function put_from_preferences(slot_index)
  local track = renoise.song().selected_track
  local pattern = renoise.song().selected_pattern
  local current_line_index = renoise.song().selected_line_index

  -- Retrieve the slot text from preferences
  local slot_key = "Slot" .. string.format("%02d", slot_index)
  local slot_text = preferences.OctaMEDPickPutSlots[slot_key].value

  if slot_text == "" or slot_text == "Slot " .. string.format("%02d", slot_index) .. ": Empty" then
    renoise.app():show_status("Slot " .. string.format("%02d", slot_index) .. " is empty in preferences.")
    return
  end

  -- Split the text into note data and effect data
  local parts = string_split(slot_text, "||")
  local note_data = string_split(parts[1] or "", "|")
  local effect_data = string_split(parts[2] or "", "|")

  local process_note_columns = true
  if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    process_note_columns = false
  end

  -- If there are no note columns in the slot data, do not overwrite current note columns
  if not note_data or #note_data == 0 or note_data[1]:match("^%s*$") then
    process_note_columns = false
  end

  -- Determine the lines to process based on randomization and edit step
  local line_indices = {}
  local pattern_length = pattern.number_of_lines
  local edit_step = renoise.song().transport.edit_step
  local start_line = current_line_index

  if randomize_enabled then
    local total_steps = pattern_length
    local step = 1

    if use_edit_step_for_put and edit_step > 0 then
      step = edit_step
      total_steps = math.floor((pattern_length - start_line + 1) / step)
    end

    for i = start_line, pattern_length, step do
      if math.random(100) <= randomize_percentage then
        table.insert(line_indices, i)
      end
    end
  else
    if use_edit_step_for_put and edit_step > 0 then
      table.insert(line_indices, current_line_index)
      renoise.song().selected_line_index = math.min(current_line_index + edit_step, pattern_length)
    else
      table.insert(line_indices, current_line_index)
    end
  end

  for _, line_index in ipairs(line_indices) do
    local pattern_line = pattern.tracks[renoise.song().selected_track_index].lines[line_index]

    -- Process Note Columns if applicable
    if process_note_columns then
      -- Update the number of visible note columns to fit the picked data
      if #note_data > track.visible_note_columns then
        track.visible_note_columns = #note_data
      end

      -- Process and write to all note columns
      for i = 1, math.min(#note_data, track.visible_note_columns) do
        local note_column = pattern_line.note_columns[i]
        local note_parts = string_split(note_data[i]:gsub("^%s+", ""), " ")  -- Remove leading spaces

        -- Assign the note column values only if they are not empty
        if note_parts[1] ~= "---" and note_parts[1] ~= "..." then
          note_column.note_string = note_parts[1]
        end

        if note_parts[2] ~= ".." then
          if set_to_selected_instrument then
            note_column.instrument_value = renoise.song().selected_instrument_index - 1
          else
            note_column.instrument_string = note_parts[2]
          end
        end

        if note_parts[3] ~= ".." then
          renoise.song().selected_track.volume_column_visible = true
          note_column.volume_string = note_parts[3]
        end

        if note_parts[4] ~= ".." then
          renoise.song().selected_track.panning_column_visible = true
          note_column.panning_string = note_parts[4]
        end

        if note_parts[5] ~= ".." then
                  renoise.song().selected_track.delay_column_visible = true

          note_column.delay_string = note_parts[5]
        end

        -- Handle samplefx data
        if #note_parts > 5 and note_parts[6] ~= "...." then
          renoise.song().selected_track.sample_effects_column_visible = true
          note_column.effect_number_string = note_parts[6]:sub(1, 2) -- Effect command
          note_column.effect_amount_string = note_parts[6]:sub(3, 4) -- Effect value
        end
      end
    end

    -- After processing note columns, call put_effect_columns for effect data
    if effect_data and #effect_data > 0 and effect_data[1] ~= "" then
      put_effect_columns(effect_data, {line_index})
    end
  end

  -- Update status and return focus to pattern editor
  renoise.app():show_status("Put: Slot " .. string.format("%02d", slot_index) .. " from preferences.")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

local function pick_to_preferences(slot_index)
  local track = renoise.song().selected_track
  local pattern_line = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index]

  local note_columns_str = {}
  local effect_columns_str = {}

  -- Process Note Columns if applicable
  if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    for i = 1, track.visible_note_columns do
      local note_column = pattern_line.note_columns[i]
      local note_str = note_column.note_string .. " " ..
                       note_column.instrument_string .. " " ..
                       note_column.volume_string .. " " ..
                       note_column.panning_string .. " " ..
                       note_column.delay_string .. " "

      -- Handle Sample FX column, if empty, put "...."
      if note_column.effect_number_string == "00" and note_column.effect_amount_string == "00" then
        note_str = note_str .. "...."
      else
        note_str = note_str .. note_column.effect_number_string .. note_column.effect_amount_string
      end

      table.insert(note_columns_str, note_str)
    end
  end

  -- Process Effect Columns
  local last_non_empty_effect_index = 0
  for i = 1, track.visible_effect_columns do
    local effect_column = pattern_line.effect_columns[i]
    local effect_str = effect_column.number_string .. effect_column.amount_string

    -- If the effect column is not empty, update the last non-empty index
    if effect_str ~= "0000" then
      last_non_empty_effect_index = i
    end

    -- Collect all effect columns
    table.insert(effect_columns_str, effect_str)
  end

  -- Truncate effect columns after the last non-empty column
  effect_columns_str = {unpack(effect_columns_str, 1, last_non_empty_effect_index)}

  -- Combine Note and Effect Columns
  local slot_text = table.concat(note_columns_str, " | ") .. "||" .. table.concat(effect_columns_str, "|")

  -- Update the corresponding textfield
  vb.views["slot_display_"..string.format("%02d", slot_index)].text = slot_text

  -- Save the picked slot data
  save_slot_to_preferences(slot_index)
end

-- Function to handle picking note and instrument data
local function pick_note_instrument(slot_index)
  pick_to_preferences(slot_index)
  renoise.app():show_status("Picked to Slot " .. string.format("%02d", slot_index))
end

-- Function to save dialog content to a text file
local function save_dialog_content_to_file()
  local filename = renoise.app():prompt_for_filename_to_write(".txt", "Save Pick/Put Dialog Content")
  if filename and filename ~= "" then
    local file, err = io.open(filename, "w")
    if file then
      for i = 1, 10 do
        local slot_text = vb.views["slot_display_"..string.format("%02d", i)].text
        file:write(slot_text, "\n")
      end
      file:close()
      renoise.app():show_status("Dialog content saved to " .. filename)
    else
      renoise.app():show_warning("Error saving file: " .. err)
    end
  end
end

-- Function to load dialog content from a text file
local function load_dialog_content_from_file()
  local filename = renoise.app():prompt_for_filename_to_read({"*.txt", "*.TXT", "*.Txt", "*"}, "Load Pick/Put Dialog Content")
  if filename and filename ~= "" then
    local file, err = io.open(filename, "r")
    if file then
      local i = 1
      for line in file:lines() do
        if i > 10 then break end
        vb.views["slot_display_"..string.format("%02d", i)].text = line
        -- Update preferences
        local slot_key = "Slot" .. string.format("%02d", i)
        preferences.OctaMEDPickPutSlots[slot_key].value = line
        i = i + 1
      end
      file:close()
      renoise.app():show_status("Dialog content loaded from " .. filename)
      -- Save preferences after loading
      renoise.tool().preferences:save_as("preferences.xml")
    else
      renoise.app():show_warning("Error loading file: " .. err)
    end
  end
end

-- Custom key handler function to allow key events to pass through to pattern editor
local function my_keyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    return
  end

  -- Allow other keys to pass through to the pattern editor
  return key
end

-- Function to toggle the visibility of the dialog
function toggle_paketti_pick_dialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
  else
    dialog = renoise.app():show_custom_dialog(
      "Paketti OctaMED Pick/Put",
      create_paketti_pick_dialog(),
      my_keyhandler_func
    )
  end
  load_slots_from_preferences()

  -- Ensure focus returns to pattern editor
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to create the GUI dialog
function create_paketti_pick_dialog()
  vb = renoise.ViewBuilder()

  local rows = {}
  for i = 1, 10 do
    rows[#rows+1] = vb:row{
      vb:button{text="Pick " .. string.format("%02d", i), notifier=function()
        pick_note_instrument(i)
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end},
      vb:button{text="Put " .. string.format("%02d", i), notifier=function()
        put_note_instrument(i)
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end},
      vb:textfield{id="slot_display_"..string.format("%02d", i), text="Slot " .. string.format("%02d", i) .. ": Empty", width=800},
      vb:button{text="Clear", notifier=function()
        clear_pick(i)
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end}
    }
  end

  return vb:column{
    vb:row{
      vb:checkbox{
        value=set_to_selected_instrument,
        notifier=function(value)
          set_to_selected_instrument = value
          save_checkbox_preference()
        end
      },
      vb:text{text="Set to Selected Instrument"}
    },
    vb:row{
      vb:checkbox{
        value=use_edit_step_for_put,
        notifier=function(value)
          use_edit_step_for_put = value
          save_checkbox_preference()
        end
      },
      vb:text{text="Use EditStep for Put"}
    },
    vb:row{
      vb:checkbox{
        id = "randomize_checkbox",
        value = randomize_enabled,
        notifier = function(value)
          randomize_enabled = value
          save_checkbox_preference()
        end
      },
      vb:text{text="Randomize"},
      vb:slider{
        id = "randomize_slider",
        min = 0,
        max = 100,
        value = randomize_percentage,
        notifier = function(value)
          randomize_percentage = value
          vb.views["randomize_percentage_label"].text = tostring(math.floor(value)) .. "%"
          save_checkbox_preference()
        end
      },
      vb:text{id = "randomize_percentage_label", text = tostring(randomize_percentage) .. "%"}
    },
    vb:row{
      vb:button{
        text = "Save Slots",
        notifier = function()
          save_dialog_content_to_file()
        end
      },
      vb:button{
        text = "Load Slots",
        notifier = function()
          load_dialog_content_from_file()
        end
      }
    },
    vb:column(rows)
  }
end

-- Function to clear the current row
function clear_columns()
  local pattern_line = renoise.song().selected_pattern.tracks[renoise.song().selected_track_index].lines[renoise.song().selected_line_index]
  local note_column = renoise.song().selected_note_column

  note_column:clear()

  for i = 1, #pattern_line.effect_columns do
    pattern_line.effect_columns[i]:clear()
  end

  renoise.app():show_status("Columns cleared!")
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

for i = 1, 10 do
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:OctaMED Pick Slot "..formatDigits(2,i),invoke=function() pick_note_instrument(i) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:OctaMED Put Slot "..formatDigits(2,i),invoke=function() put_from_preferences(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:OctaMED Pick Slot "..formatDigits(2,i),invoke=function() pick_note_instrument(i) end}
  renoise.tool():add_midi_mapping{name="Paketti:OctaMED Put Slot "..formatDigits(2,i),invoke=function() put_from_preferences(i) end}
end


renoise.tool():add_keybinding{name="Pattern Editor:Paketti:OctaMED Pick/Put Dialog",invoke=function() toggle_paketti_pick_dialog() end}
renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:OctaMED Pick/Put Dialog",invoke=function() toggle_paketti_pick_dialog() end}

------
-- Function to spread notes across multiple columns
function NoteSpread(num_columns)
  if num_columns < 1 or num_columns > 12 then
    renoise.app():show_status("Please choose a number of columns between 1 and 12.")
    return
  end

  local song = renoise.song()
  local track = song.selected_track
  local track_idx = song.selected_track_index
  local pattern = song.selected_pattern
  local pattern_lines = pattern.number_of_lines
  local current_visible_columns = track.visible_note_columns

  print("Starting NoteSpread with num_columns =", num_columns)
  print("Current visible note columns:", current_visible_columns)

  -- Gather all existing notes from all visible columns
  local note_list = {}
  local notes_found = false

  -- First pass: collect all notes from visible columns
  for line_idx = 1, pattern_lines do
    local line = pattern.tracks[track_idx].lines[line_idx]
    for col_idx = 1, current_visible_columns do
      local note_col = line.note_columns[col_idx]
      if not note_col.is_empty then
        notes_found = true
        local note_copy = {
          note_value = note_col.note_value,
          instrument_value = note_col.instrument_value,
          volume_value = note_col.volume_value,
          panning_value = note_col.panning_value,
          delay_value = note_col.delay_value,
        }
        table.insert(note_list, {
          line = line_idx,
          note = note_copy,
          original_col = col_idx
        })
        -- Clear the original note
        note_col:clear()
      end
    end
  end

  if not notes_found then
    renoise.app():show_status("No notes found in any columns.")
    return
  end

  -- Sort notes by line number to maintain order
  table.sort(note_list, function(a, b) return a.line < b.line end)

  -- Set visible note columns
  track.visible_note_columns = num_columns

  if num_columns == 1 then
    -- Special handling for single column: maintain temporal order only
    for _, note_data in ipairs(note_list) do
      local line = pattern.tracks[track_idx].lines[note_data.line]
      local target_col = line.note_columns[1]

      target_col.note_value = note_data.note.note_value
      target_col.instrument_value = note_data.note.instrument_value
      target_col.volume_value = note_data.note.volume_value
      target_col.panning_value = note_data.note.panning_value
      target_col.delay_value = note_data.note.delay_value

      print(string.format(
        "Moved note from line %d, column %d to column 1: value = %d",
        note_data.line, note_data.original_col, note_data.note.note_value
      ))
    end

    renoise.app():show_status(string.format(
      "Consolidated %d notes to single column", #note_list
    ))
  else
    -- Multiple columns: distribute notes across columns
    local column_counter = 1
    local last_column = 1

    for i, note_data in ipairs(note_list) do
      if note_data.note.note_value == 120 then -- NOTE OFF
        note_data.target_col = last_column
      else
        note_data.target_col = column_counter
        last_column = column_counter
        column_counter = (column_counter % num_columns) + 1
      end
    end

    -- Apply the new note positions
    for _, note_data in ipairs(note_list) do
      local line = pattern.tracks[track_idx].lines[note_data.line]
      local target_col = line.note_columns[note_data.target_col]

      target_col.note_value = note_data.note.note_value
      target_col.instrument_value = note_data.note.instrument_value
      target_col.volume_value = note_data.note.volume_value
      target_col.panning_value = note_data.note.panning_value
      target_col.delay_value = note_data.note.delay_value

      print(string.format(
        "Moved note from line %d, column %d to column %d: value = %d",
        note_data.line, note_data.original_col, note_data.target_col, note_data.note.note_value
      ))
    end

    renoise.app():show_status(string.format(
      "Redistributed %d notes across %d columns", #note_list, num_columns
    ))
  end
end

-- Helper function to format digits for shortcuts
local function formatDigits(min_digits, number)
  return string.format("%0" .. tostring(min_digits) .. "d", number)
end

-- Add keybindings for 1 to 12 note columns dynamically
for i = 1, 12 do
  renoise.tool():add_keybinding{name="Global:Paketti:OctaMED Note Spread " .. formatDigits(2, i),invoke=function() NoteSpread(i) end}
  renoise.tool():add_keybinding{name="Pattern Editor:Paketti:OctaMED Note Spread " .. formatDigits(2, i),invoke=function() NoteSpread(i) end}
  renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:OctaMED Note Spread " .. formatDigits(2, i),invoke=function() NoteSpread(i) end}
end

-- Add this at the top of your file with other global variables
local current_spread = 1

-- Function to increment spread
function IncrementSpread()
  current_spread = current_spread + 1
  if current_spread > 12 then
    current_spread = 1
  end
  NoteSpread(current_spread)
end

-- Function to decrement spread
function DecrementSpread()
  current_spread = current_spread - 1
  if current_spread < 1 then
    current_spread = 12
  end
  NoteSpread(current_spread)
end

-- Add these with your other keybindings
renoise.tool():add_keybinding{
  name="Global:Paketti:OctaMED Note Spread Increment",
  invoke=function() IncrementSpread() end
}
renoise.tool():add_keybinding{
  name="Pattern Editor:Paketti:OctaMED Note Spread Increment",
  invoke=function() IncrementSpread() end
}

renoise.tool():add_menu_entry{
  name="Pattern Editor:Paketti..:Other Trackers..:OctaMED Note Spread Increment",
  invoke=function() IncrementSpread() end
}

renoise.tool():add_keybinding{
  name="Global:Paketti:OctaMED Note Spread Decrement",
  invoke=function() DecrementSpread() end
}
renoise.tool():add_keybinding{
  name="Pattern Editor:Paketti:OctaMED Note Spread Decrement",
  invoke=function() DecrementSpread() end
}
renoise.tool():add_menu_entry{
  name="Pattern Editor:Paketti..:Other Trackers..:OctaMED Note Spread Decrement",
  invoke=function() DecrementSpread() end
}
-------
-- Function to toggle mute state for a specific track
function OctaMEDToggleTrackMute(track_index)
  local song = renoise.song()
  
  -- Check if track index is valid
  if track_index > #song.tracks then
    renoise.app():show_status(string.format("Track %d does not exist", track_index))
    return
  end
  
  local track = song.tracks[track_index]
  
  -- Toggle mute state using proper constants
  if track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
    track.mute_state = renoise.Track.MUTE_STATE_MUTED
  else
    track.mute_state = renoise.Track.MUTE_STATE_ACTIVE
  end
  
  -- Show status
  local status = (track.mute_state == renoise.Track.MUTE_STATE_MUTED) and "Muted" or "Unmuted"
  renoise.app():show_status(status .. " " ..renoise.song().tracks[track_index].name)
end



-- Add keybindings for tracks 1-16
for i = 1, 16 do
  renoise.tool():add_keybinding{
    name = string.format("Global:Paketti:OctaMED Toggle Mute Track %02d", i),
    invoke = function() OctaMEDToggleTrackMute(i) end
  }
  
  renoise.tool():add_keybinding{
    name = string.format("Pattern Editor:Paketti:OctaMED Toggle Mute Track %02d", i),
    invoke = function() OctaMEDToggleTrackMute(i) end
  }

  renoise.tool():add_keybinding{
    name = string.format("Mixer:Paketti:OctaMED Toggle Mute Track %02d", i),
    invoke = function() OctaMEDToggleTrackMute(i) end
  }

  renoise.tool():add_keybinding{
    name = string.format("Phrase Editor:Paketti:OctaMED Toggle Mute Track %02d", i),
    invoke = function() OctaMEDToggleTrackMute(i) end
  }  

  -- Add MIDI mapping as well
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:OctaMED Toggle Mute Track %02d", i),
    invoke = function(message)
      if message:is_trigger() then
        OctaMEDToggleTrackMute(i)
      end
    end
  }
end
-------


-- Custom key handler function to allow key events to pass through to pattern editor
local function my_keyhandler_func(dialog, key)
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
    dialog:close()
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    return
  end
  
  -- Allow other keys to pass through to the pattern editor
  return key
end

function create_echo_dialog()
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  -- Get selection info
  local selection = renoise.song().selection_in_pattern
  local selection_text = "No selection"
  local selection_length = 0
  
  if selection then
    selection_length = selection.end_line - selection.start_line + 1
    selection_text = string.format("Selection: %d...%d (length: %d)", 
      selection.start_line, selection.end_line, selection_length)
    -- Set distance to match selection length
    preferences.pakettiOctaMEDNoteEchoDistance.value = selection_length
  end
  
  local dialog_content = vb:column {
  --  margin = 10,
  --  spacing = 5,
    
    vb:text { text = selection_text, width=70 },
    
    vb:row {
      vb:text { text = "Distance", width=70 },
      vb:valuebox {
        min = 1,
        max = 16,
        value = preferences.pakettiOctaMEDNoteEchoDistance.value,
        notifier = function(value)
          preferences.pakettiOctaMEDNoteEchoDistance.value = value
        end
      }
    },    
    vb:row {
      vb:text { text = "Min Volume", width=70 },
      vb:valuebox {
        min = 1,
        max = 64,
        value = preferences.pakettiOctaMEDNoteEchoMin.value,
        notifier = function(value)
          preferences.pakettiOctaMEDNoteEchoMin.value = value
        end
      }
    },

    vb:button {
      text = "Apply",
      width = 100,
      notifier = function()
        local distance = preferences.pakettiOctaMEDNoteEchoDistance.value
        
        -- Check if distance is valid for selection
        if selection and distance < selection_length then
          renoise.app():show_status(string.format(
            "Echo distance (%d) must be at least the selection length (%d)", 
            distance, selection_length))
          return
        end
        
        CreateNoteEcho(
          preferences.pakettiOctaMEDNoteEchoDistance.value,
          preferences.pakettiOctaMEDNoteEchoMin.value
        )
        
        -- Return focus to pattern editor
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    },    
      vb:button {
        text = "Close",
        width = 100,
        notifier = function()
          dialog:close()
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      }
    
  }
  
  dialog = renoise.app():show_custom_dialog(
    "OctaMED Note Echo",
    dialog_content,
    my_keyhandler_func
  )
  
  -- Return focus to pattern editor immediately after showing dialog
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end


function CreateNoteEcho(distance, min_volume)
  local song = renoise.song()
  local pattern = song.selected_pattern
  local track = song.selected_track
  local track_idx = song.selected_track_index
  local selection = renoise.song().selection_in_pattern
  
  -- Handle selection vs single note differently
  if selection then
    -- Get the selection range
    local start_line = selection.start_line
    local end_line = selection.end_line
    local selection_length = end_line - start_line + 1
    local current_volume_factor = 1.0 -- Start at full volume
    local pattern_length = pattern.number_of_lines
    
    -- Keep track of where we're copying to
    local target_start = start_line + distance
    
    while target_start + selection_length <= pattern_length do
      -- Calculate next volume factor (1/2, 1/4, 1/8, etc.)
      current_volume_factor = current_volume_factor / 2
      
      -- Stop if we've reached minimum volume
      if current_volume_factor * 0x40 < min_volume then
        break
      end
      
      -- Copy the selection with reduced volume
      for offset = 0, selection_length - 1 do
        local source_line = pattern.tracks[track_idx].lines[start_line + offset]
        local target_line = pattern.tracks[track_idx].lines[target_start + offset]
        
        -- Copy each note column in the selection
        for col_idx = 1, track.visible_note_columns do
          local source_note = source_line.note_columns[col_idx]
          local target_note = target_line.note_columns[col_idx]
          
          -- Only copy if source has a note and target is empty
          if not source_note.is_empty and 
             target_note.is_empty and 
             target_note.note_string == "---" and
             target_note.instrument_string == ".." and
             target_note.volume_string == ".." then
            
            -- Copy note and instrument
            target_note.note_value = source_note.note_value
            target_note.instrument_value = source_note.instrument_value
            
            -- Calculate new volume
            local new_volume
            if source_note.volume_value == 255 then -- If no volume set
              new_volume = math.floor(0x7F * current_volume_factor)
            else
              new_volume = math.floor(source_note.volume_value * current_volume_factor)
            end
            target_note.volume_value = math.max(1, new_volume)
          end
        end
      end
      
      -- Move to next echo position
      target_start = target_start + distance
    end
    
    renoise.app():show_status(string.format(
      "Created selection echo (Distance: %d, Min: %02X)", 
      distance, min_volume
    ))
    
  else
    -- Original single-note echo code
    local start_line = song.selected_line_index
    local source_line = pattern.tracks[track_idx].lines[start_line]
    local source_note_col = source_line.note_columns[song.selected_note_column_index]
    
    -- Check if there's a note to echo
    if source_note_col.is_empty or source_note_col.note_value == 120 then
      renoise.app():show_status("No note to echo!")
      return
    end
    
    -- Get initial volume
    local current_volume = source_note_col.volume_value
    if current_volume == 255 then
      current_volume = 0x40
    else
      current_volume = math.floor(current_volume / 2)
    end
    
    local line_idx = start_line + distance
    
    while line_idx < pattern.number_of_lines do
      current_volume = math.floor(current_volume / 2)
      
      if current_volume < min_volume then
        break
      end
      
      local target_line = pattern.tracks[track_idx].lines[line_idx]
      local target_note_col = target_line.note_columns[song.selected_note_column_index]
      
      if target_note_col.is_empty and 
         target_note_col.note_string == "---" and
         target_note_col.instrument_string == ".." and
         target_note_col.volume_string == ".." then
        target_note_col.note_value = source_note_col.note_value
        target_note_col.instrument_value = source_note_col.instrument_value
        target_note_col.volume_value = current_volume * 2
      end
      
      line_idx = line_idx + distance
    end
    
    renoise.app():show_status(string.format(
      "Created note echo (Distance: %d, Min: %02X)", 
      distance, min_volume
    ))
  end
end

-- Add menu entry and keybinding for the dialog
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:OctaMED Note Echo Dialog",
  invoke = create_echo_dialog
}

renoise.tool():add_menu_entry{
  name = "Pattern Editor:Paketti..:Other Trackers..:OctaMED Note Echo Dialog",
  invoke = create_echo_dialog
}
---------
