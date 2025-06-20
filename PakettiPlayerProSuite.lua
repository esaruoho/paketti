local vb=renoise.ViewBuilder()
local column2=vb:column{style="group"}
local column3=vb:column{style="group"}
local hex_text2=vb:text{text="0", style="normal"}
local hex_text3=vb:text{text="0", style="normal"}
local combined_text1=vb:text{text="00", style="strong", font="bold"}
local decimal_text=vb:text{text="0", style="strong", font="bold"}  -- Add this line
local value_labels2={}
local value_labels3={}
local label_map2={} -- Add this line
local label_map3={} -- Add this line
local writing_enabled = false

local function update_combined_value()
  local combined_value=hex_text3.text..hex_text2.text
  combined_text1.text=combined_value
  
  -- Convert hex to decimal
  local decimal_value = tonumber(combined_value, 16)
  decimal_text.text = tostring(decimal_value)
    
  renoise.app():show_status(combined_text1.text .. " " .. decimal_value)

  if not renoise.song() or not writing_enabled then return end

  local song=renoise.song()
  local start_pos, end_pos
  local start_track, end_track

  if song.selection_in_pattern then
    start_pos = song.selection_in_pattern.start_line
    end_pos = song.selection_in_pattern.end_line
    start_track = song.selection_in_pattern.start_track
    end_track = song.selection_in_pattern.end_track
  else
    start_pos = song.selected_line_index
    end_pos = start_pos
    start_track = song.selected_track_index
    end_track = start_track
  end

  for track = start_track, end_track do
    for line = start_pos, end_pos do
      song:pattern(song.selected_pattern_index):track(track):line(line):effect_column(1).amount_string = combined_value
    end
  end
end

local function create_valuebox(i, column, hex_text, value_labels, label_map, position, id_prefix)
  local hex=string.format("%X",i)
  local label_id = id_prefix .. "_label_" .. hex
  local number_label=vb:text{text=hex,width=2,style="normal"}
  label_map[label_id] = number_label
  value_labels[#value_labels + 1] = number_label
  
  local valuebox=vb:valuebox{
    value=i,min=i,max=i,width=8,
    tostring=function(v)
      local hex_value=string.format("%X",v)
      hex_text.text=hex_value
      update_combined_value() -- Call the update function here
      
      for _, label in ipairs(value_labels) do 
        if label.text ~= hex_value then
          label.style="normal"
        end
      end
      number_label.style="strong"
      return hex_value
    end,
    tonumber=function(str)
      return tonumber(str,16)
    end,
    notifier=function(val)
      local hex_value=string.format("%X",val)
      for _, label in ipairs(value_labels) do 
        if label.text ~= hex_value then
          label.style="normal"
        end
      end
      label_map[id_prefix .. "_label_" .. hex_value].style = "strong"
      update_combined_value() -- Call the update function here too
    end
  }
  
  if position == "number_first" then
    column:add_child(vb:row{number_label,valuebox})
  elseif position == "valuebox_first" then
    column:add_child(vb:row{valuebox,number_label})
  end
end

for i=0,15 do
  create_valuebox(i, column3, hex_text3, value_labels3, label_map3, "number_first", "col3")
  create_valuebox(i, column2, hex_text2, value_labels2, label_map2, "valuebox_first", "col2")
end

-- Ensure that all text styles are "normal" at the start
for _, label in ipairs(value_labels2) do
  label.style = "normal"
end

for _, label in ipairs(value_labels3) do
  label.style = "normal"
end

local separator = vb:space{width=50}

dialog_content = vb:column{
  --margin=10,
  vb:row{
    vb:checkbox{
      value = writing_enabled,
      notifier=function(val)
        writing_enabled = val
      end
    },
    vb:text{text="Write", style="strong"}
  },
  vb:row{
    vb:column{column3, vb:space{width=35}},
    vb:column{column2}
  },
  vb:horizontal_aligner{mode="distribute",
    vb:column{
      combined_text1,
      decimal_text
    }
  }
}
---------------
local note_grid_vb
local note_grid_dialog

local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
local notes = {}
for octave = 0, 9 do
  for _, note in ipairs(note_names) do
    table.insert(notes, note .. octave)
  end
end
table.insert(notes, "000") -- Adding "---" as "000"
table.insert(notes, "OFF")

local switch_group={"0","0"}
local volume_switch_group={"0","0"}

local function PakettiPlayerProNoteGridInsertNoteInPattern(note, instrument, editstep)
  local song=renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local note_column_selected = false
  local step = song.transport.edit_step -- Get the current edit step value from the transport

  -- Check for valid track types first
  local start_track, end_track
  if sel then
    start_track = sel.start_track
    end_track = sel.end_track
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end
  
  local is_valid_track = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      is_valid_track = true
      break
    end
  end

  if not is_valid_track then
    renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
    return
  end

  -- Only print debug info if we have valid tracks
  print (editstep)

  local function insert_note_line(line, col)
    line:note_column(col).note_string = note_to_insert
    if note == "OFF" or note == "---" or note == "000" then
      line:note_column(col).instrument_string = ".." 
      print("Note OFF or blank inserted")
    end

    if instrument ~= nil and note ~= "000" and note ~= "OFF" then
      local instrument_actual = instrument - 1
      local instrument_string = string.format("%02X", instrument_actual)
      print("Inserting instrument string: " .. instrument_string)
      line:note_column(col).instrument_string = instrument_string
    end
    print("Note column info - Instrument String: " .. line:note_column(col).instrument_string .. ", Instrument Value: " .. tostring(line:note_column(col).instrument_value))
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  local function clear_note_line(line, col)
    line:note_column(col).note_string = "---"
    line:note_column(col).instrument_string = ".."
    line:note_column(col).volume_string = ".."
    print("Clearing note column and volume on non-editstep row")
  end

  if sel == nil then
    local line = song.selected_line
    local col = song.selected_note_column_index
    local visible_note_columns = song.selected_track.visible_note_columns
    if col > 0 and col <= visible_note_columns then
      insert_note_line(line, col)
      note_column_selected = true
    end
  else
    for track_index = sel.start_track, sel.end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_track = song.patterns[pattern_index]:track(track_index)
        local visible_note_columns = track.visible_note_columns
        local step = song.transport.edit_step
        if step == 0 then
          step = 1
        end
        -- Iterate through the lines, insert or clear based on editstep
        for line_index = sel.start_line, sel.end_line do
          local line = pattern_track:line(line_index)
          for col_index = 1, visible_note_columns do
            if (track_index > sel.start_track) or (col_index >= sel.start_column) then
              if col_index <= visible_note_columns then
                if editstep and (line_index - sel.start_line) % step ~= 0 then
                  -- If editstep is true and this line doesn't match the editstep, clear it
                  clear_note_line(line, col_index)
                else
                  -- Otherwise, insert the note
                  insert_note_line(line, col_index)
                  note_column_selected = true
                end
              end
            end
          end
        end
      end
    end
  end

  if not note_column_selected then
    renoise.app():show_status("No Note Columns were selected, doing nothing.")
  end
end

local function PakettiPlayerProNoteGridUpdateInstrumentInPattern(instrument, editstep_enabled)
  local song=renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local step = song.transport.edit_step -- Get the current edit step value from the transport

  -- Safeguard to prevent issues if edit step is set to 0
  if step == 0 then
    step = 1
  end

  local function update_instrument_line(line, col, line_index, total_lines)
    if instrument ~= nil then
      local instrument_actual = instrument - 1
      local instrument_string = string.format("%02X", instrument_actual)
      print("Updating instrument string: " .. instrument_string .. " at row " .. line_index .. " of " .. total_lines)
      line:note_column(col).instrument_string = instrument_string
    end
  end

  if sel == nil then
    -- If there's no selection, update only the currently selected note column
    local line = song.selected_line
    local col = song.selected_note_column_index
    local visible_note_columns = song.selected_track.visible_note_columns
    if col > 0 and col <= visible_note_columns then
      update_instrument_line(line, col, song.selected_line_index, 1)
    end
  else
    -- Calculate total lines in the selection for logging
    local total_lines = sel.end_line - sel.start_line + 1

    for track_index = sel.start_track, sel.end_track do
      local pattern_track = song.patterns[pattern_index]:track(track_index)
      local visible_note_columns = song:track(track_index).visible_note_columns

      -- Iterate through the lines and apply the editstep logic if enabled
      for line_index = sel.start_line, sel.end_line do
        local line = pattern_track:line(line_index)

        -- Apply editstep logic only if the checkbox is enabled
        local should_update = not editstep_enabled or (editstep_enabled and (line_index - sel.start_line) % step == 0)

        if should_update then
          print("Updating row " .. line_index .. " out of " .. total_lines .. " (editstep " .. (editstep_enabled and "enabled" or "disabled") .. ")")
          
          for col_index = 1, visible_note_columns do
            if (track_index > sel.start_track) or (col_index >= sel.start_column) then
              if col_index <= visible_note_columns then
                -- Update the instrument on lines that match the editstep or all lines if editstep is disabled
                update_instrument_line(line, col_index, line_index, total_lines)
              end
            end
          end
        else
          print("Skipping row " .. line_index .. " (editstep enabled, does not match step)")
        end
      end
    end
  end
end





local function PakettiPlayerProNoteGridUpdateInstrumentPopup()
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end
  if note_grid_vb and note_grid_vb.views["instrument_popup"] then
    note_grid_vb.views["instrument_popup"].items = instrument_items
  end
end
local EditStepCheckboxValue = false -- Shared variable to hold the checkbox state


local function PakettiPlayerProNoteGridChangeInstrument(instrument)
  -- Declare editstep_enabled outside the if block
  local editstep_enabled

  -- Check the checkbox value and set editstep_enabled accordingly
  if EditStepCheckboxValue == true then
    editstep_enabled = true
  else 
    editstep_enabled = false
  end

  -- Call the update function with the proper editstep value
  PakettiPlayerProNoteGridUpdateInstrumentInPattern(instrument, editstep_enabled)
end

-- Shared note grid configuration and creation system
local function PakettiPlayerProCreateModularNoteGrid(vb_instance, config)
  -- Default configuration
  local default_config = {
    include_editstep = false,
    editstep_checkbox_value = false,
    instrument_popup_id = "instrument_popup",
    effect_popup_id = "effect_popup", 
    effect_argument_display_id = "effect_argument_display",
    volume_display_id = "volume_display",
    note_click_callback = nil, -- Custom callback for note button clicks
    grid_rows = 11,
    grid_columns = 12,
    button_width = 35,
    button_height = 15
  }
  
  -- Merge provided config with defaults
  for key, value in pairs(default_config) do
    if config[key] == nil then
      config[key] = value
    end
  end
  
  local grid = vb_instance:column{}
  
  -- Add EditStep checkbox if requested
  if config.include_editstep then
    grid:add_child(vb_instance:row{
      vb_instance:checkbox{
        value = config.editstep_checkbox_value,
        notifier = config.editstep_notifier or function(value)
          EditStepCheckboxValue = value
        end
      },
      vb_instance:text{
        text="Fill Selection with EditStep", style="strong", font="bold"
      }
    })
  end
  
  -- Create the grid of note buttons
  for row = 1, config.grid_rows do
    local row_items = vb_instance:row{}
    for col = 1, config.grid_columns do
      local index = (row - 1) * config.grid_columns + col
      if notes[index] then
        row_items:add_child(vb_instance:button{
          text = notes[index],
          width = config.button_width,
          height = config.button_height,
          notifier = config.note_click_callback and function()
            config.note_click_callback(notes[index], vb_instance, config)
          end or function()
            -- Default behavior - just insert the note
            local instrument_value = renoise.song().selected_instrument_index
            PakettiPlayerProNoteGridInsertNoteInPattern(notes[index], instrument_value, config.editstep_checkbox_value)
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        })
      end
    end
    grid:add_child(row_items)
  end
  
  return grid
end

-- Note Grid Dialog (with EditStep) - Updated to use modular system
function PakettiPlayerProNoteGridCreateGrid()
  local config = {
    include_editstep = true,
    editstep_checkbox_value = EditStepCheckboxValue,
    editstep_notifier = function(value)
      EditStepCheckboxValue = value
    end,
    note_click_callback = function(note, vb_instance, config)
      local instrument_value = renoise.song().selected_instrument_index
      print("Note button clicked. Instrument Value: " .. tostring(instrument_value))
      PakettiPlayerProNoteGridInsertNoteInPattern(note, instrument_value, EditStepCheckboxValue)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }
  
  return PakettiPlayerProCreateModularNoteGrid(note_grid_vb, config)
end

-- Smart instrument popup updater function
local function PakettiPlayerProCreateInstrumentObserver(vb_instance, popup_id, dialog_ref)
  local function update_instrument_popup()
    if not dialog_ref or not dialog_ref.visible then
      return
    end
    
    local instrument_items = {"<None>"}
    for i = 0, #renoise.song().instruments - 1 do
      local instrument = renoise.song().instruments[i + 1]
      table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
    end
    
    local popup = vb_instance.views[popup_id]
    if popup then
      local selected_instrument_index = renoise.song().selected_instrument_index
      local selected_instrument_value = selected_instrument_index + 1
      
      popup.items = instrument_items
      popup.value = selected_instrument_value
      print("Updated popup " .. popup_id .. " to instrument: " .. tostring(selected_instrument_index))
    end
  end
  
  -- Check if notifier already exists, if not add it
  if not renoise.song().selected_instrument_index_observable:has_notifier(update_instrument_popup) then
    renoise.song().selected_instrument_index_observable:add_notifier(update_instrument_popup)
    print("Added instrument observer for " .. popup_id)
  end
  
  return update_instrument_popup
end

-- Smart cleanup function
local function PakettiPlayerProRemoveInstrumentObserver(update_function)
  if renoise.song().selected_instrument_index_observable:has_notifier(update_function) then
    renoise.song().selected_instrument_index_observable:remove_notifier(update_function)
    print("Removed instrument observer")
  end
end

local function PakettiPlayerProNoteGridCloseDialog()
  if note_grid_dialog and note_grid_dialog.visible then
    note_grid_dialog:close()
  end
  
  -- Clean up instrument observer
  if note_grid_instrument_observer then
    PakettiPlayerProRemoveInstrumentObserver(note_grid_instrument_observer)
    note_grid_instrument_observer = nil
  end
  
  note_grid_dialog = nil
  print("Dialog closed.")
  renoise.app():show_status("Closing Paketti PlayerPro Note Dialog")
end

local function PakettiPlayerProNoteGridCreateDialogContent()
  note_grid_vb = renoise.ViewBuilder()
local EditStepCheckboxValue = false -- Initial value for EditStepCheckbox

  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end

  local selected_instrument_index = renoise.song().selected_instrument_index
  local selected_instrument_value = selected_instrument_index + 1
  print("Dialog opened. Selected Instrument Index: " .. tostring(selected_instrument_index) .. ", Selected Instrument Value: " .. tostring(selected_instrument_value))

  return note_grid_vb:column{
    --margin=10,
    width="100%",
    note_grid_vb:row{
      note_grid_vb:text{
        text="Instrument",style="strong",font="bold"
      },
      note_grid_vb:popup{
        items = instrument_items,
        width=265,
        id = "note_grid_instrument_popup",  -- Changed ID to be unique
        value = selected_instrument_value,
        notifier=function(value)
          local instrument
          if value == 1 then
            instrument = nil
            renoise.song().selected_instrument_index = nil
          else
            instrument = value - 1
            renoise.song().selected_instrument_index = instrument
          end
          print("Instrument dropdown changed. Value: " .. tostring(value) .. ", Instrument Index: " .. tostring(instrument))
          PakettiPlayerProNoteGridChangeInstrument(instrument)
        end
      },
      note_grid_vb:button{
        text="Refresh",
        width=90,
        notifier=function()
          PakettiPlayerProNoteGridUpdateInstrumentPopup()
        end
      }
    },
     PakettiPlayerProNoteGridCreateGrid(),
    note_grid_vb:row{
      note_grid_vb:button{
        text="Close",
        width=420,
        notifier=function()
          PakettiPlayerProNoteGridCloseDialog()
        end
      }
    }
  }
end

-- Global variable to store the observer function
-- note_grid_instrument_observer is now declared at the top of the file

function pakettiPlayerProNoteGridShowDropdownGrid()
renoise.app().window.active_middle_frame=1

  if note_grid_dialog and note_grid_dialog.visible then
    print("Dialog is visible, closing dialog.")
    PakettiPlayerProNoteGridCloseDialog()
  else
    print("Dialog is not visible, creating new dialog.")
    note_grid_dialog = renoise.app():show_custom_dialog("Player Pro Note Selector with EditStep", PakettiPlayerProNoteGridCreateDialogContent(),my_keyhandler_func)
    
    -- Add instrument observer after dialog is created
    note_grid_instrument_observer = PakettiPlayerProCreateInstrumentObserver(note_grid_vb, "note_grid_instrument_popup", note_grid_dialog)
    
    print("Dialog opened.")
    renoise.app():show_status("Opening Paketti PlayerPro Note Dialog")
    -- Return focus to the Pattern Editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end

local function PakettiPlayerProNoteGridAddNoteMenuEntries()
  local note_ranges = {
    {name="C-0 to B-2", range_start = 1, range_end = 36},
    {name="C-3 to B-5", range_start = 37, range_end = 72},
    {name="C-6 to B-9", range_start = 73, range_end = 108}
  }

  for _, range in ipairs(note_ranges) do
    for i = range.range_start, range.range_end do
      if notes[i] then
        renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Note Dropdown.."..range.name..":"..notes[i],
          invoke=function() PakettiPlayerProNoteGridInsertNoteInPattern(notes[i], renoise.song().selected_instrument_index) end}
      end
    end
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Note Dropdown.."..range.name..":000",invoke=function() PakettiPlayerProNoteGridInsertNoteInPattern("000", renoise.song().selected_instrument_index) end}
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti:Other Trackers:Note Dropdown.."..range.name..":OFF",invoke=function() PakettiPlayerProNoteGridInsertNoteInPattern("OFF", renoise.song().selected_instrument_index) end}
  end
end

-- Handle scenario when the dialog is closed by other means
renoise.app().window.active_middle_frame_observable:add_notifier(function()
  if note_grid_dialog and not note_grid_dialog.visible then
    print("Dialog is not visible, removing reference.")
    PakettiPlayerProNoteGridCloseDialog()
    print("Reference removed.")
  end
end)

renoise.tool():add_keybinding{name="Global:Paketti:Open Player Pro Note Column Dialog...",invoke=pakettiPlayerProNoteGridShowDropdownGrid}

PakettiPlayerProNoteGridAddNoteMenuEntries()
--------------
function pakettiPlayerProTranspose(steps, range, playback)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local pattern = song.selected_pattern

  -- Determine the range to transpose
  local start_track, end_track, start_line, end_line, start_column, end_column

  if selection ~= nil then
    start_track = selection.start_track
    end_track = selection.end_track
    start_line = selection.start_line
    end_line = selection.end_line
    start_column = selection.start_column
    end_column = selection.end_column
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
    start_line = song.selected_line_index
    end_line = song.selected_line_index
    
    if range == "notecolumn" then
      -- For notecolumn range, only affect the selected column
      start_column = song.selected_note_column_index
      end_column = song.selected_note_column_index
    else -- "row"
      -- For row range, affect all visible columns
      start_column = 1
      end_column = song.tracks[start_track].visible_note_columns
    end
  end

  -- Iterate through each track in the determined range
  for track_index = start_track, end_track do
    local track = pattern:track(track_index)
    local tracks = renoise.song().tracks[track_index]

    -- Set the column range for each track based on the selection
    local first_column = (track_index == start_track) and start_column or 1
    local last_column = (track_index == end_track) and end_column or tracks.visible_note_columns

    -- Iterate through each line in the determined range
    for line_index = start_line, end_line do
      local line = track:line(line_index)

      -- Iterate through each note column in the line within the selected range
      for column_index = first_column, last_column do
        local note_column = line:note_column(column_index)
        if not note_column.is_empty then
          -- Skip transposing if note_value is 120 or 121
          if note_column.note_value < 120 then
            note_column.note_value = (note_column.note_value + steps) % 120
          end
        end
      end
    end
  end
  
  -- If playback is enabled, trigger the current line
  if playback then
    song:trigger_pattern_line(song.selected_line_index)
  end
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +1",invoke=function() pakettiPlayerProTranspose(1, "row", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -1",invoke=function() pakettiPlayerProTranspose(-1, "row", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +12",invoke=function() pakettiPlayerProTranspose(12, "row", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -12",invoke=function() pakettiPlayerProTranspose(-12, "row", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column +1",invoke=function() pakettiPlayerProTranspose(1, "notecolumn", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column -1",invoke=function() pakettiPlayerProTranspose(-1, "notecolumn", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column +12",invoke=function() pakettiPlayerProTranspose(12, "notecolumn", false) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column -12",invoke=function() pakettiPlayerProTranspose(-12, "notecolumn", false) end}

-- Transpose with Play/Audition versions
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +1 with Play",invoke=function() pakettiPlayerProTranspose(1, "row", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -1 with Play",invoke=function() pakettiPlayerProTranspose(-1, "row", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +12 with Play",invoke=function() pakettiPlayerProTranspose(12, "row", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -12 with Play",invoke=function() pakettiPlayerProTranspose(-12, "row", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column +1 with Play",invoke=function() pakettiPlayerProTranspose(1, "notecolumn", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column -1 with Play",invoke=function() pakettiPlayerProTranspose(-1, "notecolumn", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column +12 with Play",invoke=function() pakettiPlayerProTranspose(12, "notecolumn", true) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Note Column -12 with Play",invoke=function() pakettiPlayerProTranspose(-12, "notecolumn", true) end}
--------------------
local effect_dialog_vb = renoise.ViewBuilder()
local effect_dialog

local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
local notes = {}
for octave = 0, 9 do
  for _, note in ipairs(note_names) do
    table.insert(notes, note .. octave)
  end
end
table.insert(notes, "000") -- Adding "---" as "000"
table.insert(notes, "OFF")

local effect_descriptions = {
  "0Axy - Arpeggio (x=base note offset1, y=base note offset 2) *",
  "0Uxx - Pitch Slide up (00-FF) *",
  "0Dxx - Pitch Slide down (00-FF) *",
  "0Gxx - Glide to note with step xx (00-FF)*",
  "0Ixx - Volume Slide Up with step xx (00-64) (64x0601 or 2x0632 = slide0-full) *",
  "0Oxx - Volume Slide Down with step xx (00-64) *",
  "0Cxy - Volume slicer -- x=factor (0=0.0, F=1.0), slice at tick y. *",
  "0Qxx - Delay notes in track-row xx ticks before playing. (00-speed)",
  "0Mxx - Set Channel volume (00-FF)",
  "0Sxx - Trigger Sample Offset, 00 is sample start, FF is sample end. *",
  "0Bxx - Play Sample Backwards (B00) or forwards again (B01) *",
  "0Rxy - Retrig notes in track-row every xy ticks (x=volume; y=ticks 0 - speed) **",
  "0Yxx - Maybe trigger line with probability xx, 00 = mutually exclusive note columns",
  "0Zxx - Trigger Phrase xx (Phrase Number (01-7E), 00 = none, 7F = keymap)",
  "0Vxy - Set Vibrato x= speed, y= depth; x=(0-F); y=(0-F)*",
  "0Txy - Set Tremolo x= speed, y= depth",
  "0Nxy - Set Auto Pan, x= speed, y= depth",
  "0Exx - Set Active Sample Envelope's Position to Offset XX",
  "0Lxx - Set track-Volume (00-FF)",
  "0Pxx - Set Panning (00-FF) (00: left; 80: center; FF: right)",
  "0Wxx - Surround Width (00-FF) *",
  "0Jxx - Set Track's Output Routing to channel XX",
  "0Xxx - Stop all notes and FX (xx = 00), or only effect xx (xx > 00)",
  "ZTxx - Set tempo to xx BPM (14-FF, 00 = stop song)",
  "ZLxx - Set Lines Per Beat (LPB) to xx lines",
  "ZKxx - Set Ticks Per Line (TPL) to xx ticks (01-10)",
  "ZGxx - Enable (xx = 01) or disable (xx = 00) Groove",
  "ZBxx - Break pattern and jump to line xx in next",
  "ZDxx - Delay (pause) pattern for xx lines"
}

local function update_instrument_popup()
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end
  
  local popup = effect_dialog.views.effect_dialog_instrument_popup  -- Updated ID reference
  popup.items = instrument_items
end

local function get_selected_instrument()
  if not effect_dialog or not effect_dialog.visible then
    return nil
  end
  
  local popup = effect_dialog.views.effect_dialog_instrument_popup  -- Updated ID reference
  local selected_index = popup.value
  
  if selected_index == 1 then  -- "<None>" is selected
    return nil
  end
  
  return renoise.song().instruments[selected_index - 1]
end

local function pakettiPlayerProInsertIntoLine(line, col, note, instrument, effect, effect_argument, volume)
  if note then
    line:note_column(col).note_string = note
  end
  if instrument and note ~= "---" and note ~= "OFF" then
    line:note_column(col).instrument_value = instrument
  end
  if effect and effect ~= "Off" and note ~= "---" and note ~= "OFF" then
    line:effect_column(col).number_string = effect
    line:effect_column(col).amount_string = effect_argument ~= "00" and effect_argument or "00"
  end
  if volume and volume ~= "Off" and note ~= "---" and note ~= "OFF" then
    line:note_column(col).volume_string = volume
  end
end

local function pakettiPlayerProInsertNoteInPattern(note, instrument, effect, effect_argument, volume)
  local song=renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local note_column_selected = false

  -- Check for valid track types first
  local start_track, end_track
  if sel then
    start_track = sel.start_track
    end_track = sel.end_track
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end
  
  local is_valid_track = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      is_valid_track = true
      break
    end
  end

  if not is_valid_track then
    renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
    return
  end

  -- Debug logs - only print if we have valid tracks
  print("Inserting note: " .. (note or "N/A"))
  if instrument then print("Instrument: " .. instrument) end
  if effect then print("Effect: " .. effect) end
  if effect_argument then print("Effect Argument: " .. effect_argument) end
  if volume then print("Volume: " .. volume) end

  if sel then
    print("Selection in pattern:")
    print("  start_track: " .. sel.start_track .. ", end_track: " .. sel.end_track)
    print("  start_line: " .. sel.start_line .. ", end_line: " .. sel.end_line)
    print("  start_column: " .. sel.start_column .. ", end_column: " .. sel.end_column)
  else
    print("No selection in pattern.")
  end

  if sel == nil then
    local line = song.selected_line
    local col = song.selected_note_column_index
    local visible_note_columns = song.selected_track.visible_note_columns
    if col > 0 and col <= visible_note_columns then
      pakettiPlayerProInsertIntoLine(line, col, note_to_insert, instrument, effect, effect_argument, volume)
      note_column_selected = true
      print("Inserted note (" .. (note_to_insert or "N/A") .. ") at track " .. song.selected_track_index .. " (" .. song.selected_track.name .. "), line " .. song.selected_line_index .. ", column " .. col)
    end
  else
    for track_index = sel.start_track, sel.end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_track = song.patterns[pattern_index]:track(track_index)
        local visible_note_columns = track.visible_note_columns
        for line_index = sel.start_line, sel.end_line do
          local line = pattern_track:line(line_index)
          for col_index = 1, visible_note_columns do
            if (track_index > sel.start_track) or (col_index >= sel.start_column) then
              if col_index <= visible_note_columns then
                pakettiPlayerProInsertIntoLine(line, col_index, note_to_insert, instrument, effect, effect_argument, volume)
                note_column_selected = true
                print("Inserted note (" .. (note_to_insert or "N/A") .. ") at track " .. track_index .. " (" .. track.name .. "), line " .. line_index .. ", column " .. col_index)
              end
            end
          end
        end
      end
    end
  end

  if not note_column_selected then
    renoise.app():show_status("No Note Columns were selected, doing nothing.")
  end
end

-- Main Dialog Note Grid - Updated to use modular system  
local function pakettiPlayerProCreateMainNoteGrid(main_vb)
  local config = {
    include_editstep = true,
    instrument_popup_id = "main_dialog_instrument_popup",
    effect_popup_id = "main_effect_popup",
    effect_argument_display_id = "main_effect_argument_display",
    volume_display_id = "main_volume_display",
    note_click_callback = function(note, vb_instance, config)
      local instrument_value = vb_instance.views[config.instrument_popup_id].value - 2
      local instrument = instrument_value >= 0 and instrument_value or nil
      
      -- Extract effect code from selected effect description
      local effect = nil
      local effect_popup_value = vb_instance.views[config.effect_popup_id].value
      if effect_popup_value > 1 then
        local effect_description = vb_instance.views[config.effect_popup_id].items[effect_popup_value]
        -- Extract the effect code (e.g., "0A" from "0Axy - Arpeggio...")
        effect = string.match(effect_description, "^(%w%w)")
      end
      
      local effect_argument = vb_instance.views[config.effect_argument_display_id].text
      local volume = vb_instance.views[config.volume_display_id].text
      
      -- Use the new function that handles both EditStep and effects/volume
      pakettiPlayerProMainDialogInsertNoteInPattern(note, instrument, effect, effect_argument, volume, EditStepCheckboxValue)
      
      print("Inserted: " .. note .. " with EditStep: " .. tostring(EditStepCheckboxValue) .. ", Volume: " .. volume .. ", Effect: " .. tostring(effect))
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }
  
  return PakettiPlayerProCreateModularNoteGrid(main_vb, config)
end

-- Global dialog variable for effect dialog
local effect_fx_dialog = nil

function pakettiPlayerProEffectDialog()
  if effect_fx_dialog and effect_fx_dialog.visible then
    effect_fx_dialog:close()
    effect_fx_dialog = nil
    return
  end
  
  effect_fx_dialog = renoise.app():show_custom_dialog("FX", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

---------------

local function pakettiPlayerProCreateArgumentColumn(column_index, switch_group, update_display)
  return effect_dialog_vb:switch{
    items = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"},
    width=170,
    height = 20,
    value = 1, -- default to "Off"
    notifier=function(idx)
      switch_group[column_index] = idx == 1 and "0" or string.format("%X", idx - 1)
      update_display()
    end
  }
end

local function pakettiPlayerProUpdateEffectArgumentDisplay()
  local arg_display = switch_group[1] .. switch_group[2]
  effect_dialog_vb.views["effect_argument_display"].text = arg_display == "00" and "00" or arg_display
end

local function pakettiPlayerProUpdateVolumeDisplay()
  local vol_display = volume_switch_group[1] .. volume_switch_group[2]
  effect_dialog_vb.views["volume_display"].text = vol_display == "00" and "00" or vol_display
end

-- Global dialog variable for main dialog
local dialog = nil
local main_dialog_instrument_observer = nil
local main_vb = nil  -- Make main_vb global
local main_switch_group = {"0","0"}  -- Make main_switch_group global

function pakettiPlayerProShowMainDialog()
  if dialog and dialog.visible then
    -- Clean up observer before closing
    if main_dialog_instrument_observer then
      PakettiPlayerProRemoveInstrumentObserver(main_dialog_instrument_observer)
      main_dialog_instrument_observer = nil
    end
    dialog:close()
    dialog = nil
    return
  end

  -- Create new ViewBuilder instance for this dialog
  main_vb = renoise.ViewBuilder()

  -- Get the currently selected instrument to set as initial popup value
  local selected_instrument_index = renoise.song().selected_instrument_index
  local selected_instrument_value = selected_instrument_index + 1

  -- Create effect items array with "None" as first item, then all effect descriptions
  local effect_items = {"None"}
  for _, description in ipairs(effect_descriptions) do
    table.insert(effect_items, description)
  end

  -- Create instrument items array
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end

  local function update_main_instrument_popup()
    local instrument_items = {"<None>"}
    for i = 0, #renoise.song().instruments - 1 do
      local instrument = renoise.song().instruments[i + 1]
      table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
    end
    
    local popup = main_vb.views["main_dialog_instrument_popup"]
    popup.items = instrument_items
  end

  local main_volume_switch_group = {"0","0"}

  local function pakettiPlayerProCreateMainArgumentColumn(column_index, switch_group, update_display)
    local switch_config = {
      items = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"},
      width=220,
      height = 20,
      value = 1, -- default to "0"
      notifier=function(idx)
        switch_group[column_index] = idx == 1 and "0" or string.format("%X", idx - 1)
        update_display()
      end
    }
    
    -- Add ID to the lower effect value switch (column 2) so we can access it via MIDI
    if column_index == 2 then
      switch_config.id = "main_effect_lower_switch"
    end
    
    return main_vb:switch(switch_config)
  end

  local function pakettiPlayerProCreateMainVolumeColumn(column_index, switch_group, update_display)
    -- First digit (column_index 1): 0-8 only (volume max is 80 hex)
    -- Second digit (column_index 2): 0-F full range
    local items
    if column_index == 1 then
      items = {"0", "1", "2", "3", "4", "5", "6", "7", "8"}
    else
      items = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
    end
    
    return main_vb:switch{
      items = items,
      width=250,
      height = 20,
      value = 1, -- default to "0"
      id = "volume_switch_" .. column_index,
      notifier=function(idx)
        if column_index == 1 then
          -- First digit: 0-8 range
          switch_group[column_index] = tostring(idx - 1)
          -- If first digit is set to 8, reset second digit to 0
          if idx - 1 == 8 then
            switch_group[2] = "0"
            -- Update the second switch to show 0
            local second_switch = main_vb.views["volume_switch_2"]
            if second_switch then
              second_switch.value = 1 -- Index 1 corresponds to "0"
            end
          end
        else
          -- Second digit: 0-F range, but check if first digit is 8
          if switch_group[1] == "8" and idx > 1 then
            -- If first digit is 8, only allow 0 for second digit
            switch_group[column_index] = "0"
            -- Reset the switch back to 0
            main_vb.views["volume_switch_2"].value = 1
          else
            switch_group[column_index] = idx == 1 and "0" or string.format("%X", idx - 1)
          end
        end
        update_display()
      end
    }
  end

  function pakettiPlayerProUpdateMainEffectDropdown()
    -- Get current effect argument values
    local arg_display = main_switch_group[1] .. main_switch_group[2]
    
    -- Print detailed information when effect dropdown changes
    local song = renoise.song()
    local sel = song.selection_in_pattern
    local editstep_status = EditStepCheckboxValue and "ENABLED" or "DISABLED"
    local step = song.transport.edit_step
    
    print("=== MAIN DIALOG EFFECT DROPDOWN CHANGED ===")
    print("Effect Argument: " .. arg_display)
    print("EditStep: " .. editstep_status .. " (step size: " .. step .. ")")
    
    -- Check for valid track types first
    local start_track, end_track
    if sel then
      start_track = sel.start_track
      end_track = sel.end_track
    else
      start_track = song.selected_track_index
      end_track = song.selected_track_index
    end
    
    local is_valid_track = false
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        is_valid_track = true
        break
      end
    end

    if not is_valid_track then
      renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Effect Columns. Doing nothing.")
      return
    end
    
    -- Get the selected effect from the popup
    local effect = nil
    local effect_popup_value = main_vb.views["main_effect_popup"].value
    local write_effect_command = false
    
    if effect_popup_value > 1 then
      local effect_description = effect_items[effect_popup_value]
      -- Extract the effect code (e.g., "0A" from "0Axy - Arpeggio...")
      effect = string.match(effect_description, "^(%w%w)")
      write_effect_command = true
      print("Using effect: " .. effect)
    else
      print("Effect dropdown is 'None' - clearing effect commands")
    end
    
    local pattern_index = song.selected_pattern_index
    local effect_column_selected = false
    
    if step == 0 then
      step = 1
    end
    
    local function insert_effect_line(line, col, track_idx, line_idx)
      if write_effect_command then
        line:effect_column(col).number_string = effect
      end
      line:effect_column(col).amount_string = arg_display
      if write_effect_command then
        print("  Set effect " .. effect .. arg_display .. " at track " .. song:track(track_idx).name .. ", line " .. line_idx .. ", column " .. col)
      else
        print("  Set effect argument " .. arg_display .. " at track " .. song:track(track_idx).name .. ", line " .. line_idx .. ", column " .. col)
      end
    end
    
    local function clear_effect_line(line, col)
      line:effect_column(col).number_string = ".."
      line:effect_column(col).amount_string = ".."
      print("  Clearing effect column on non-editstep row")
    end
    
    -- Count affected columns and tracks for status message
    local affected_tracks = {}
    local total_columns = 0
    
    if sel == nil then
      local line = song.selected_line
      local col = song.selected_effect_column_index
      if col > 0 and col <= song.selected_track.visible_effect_columns then
        insert_effect_line(line, col, song.selected_track_index, song.selected_line_index)
        effect_column_selected = true
        affected_tracks[song.selected_track_index] = 1
        total_columns = 1
      end
    else
      -- Use the same pattern as PakettiPatternEditorCheatSheet.lua
      for track_index = sel.start_track, sel.end_track do
        local track = song:pattern(pattern_index):track(track_index)
        local trackvis = song:track(track_index)
        if trackvis.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local note_columns_visible = trackvis.visible_note_columns
          local effect_columns_visible = trackvis.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible

          local start_column = (track_index == sel.start_track) and sel.start_column or 1
          local end_column = (track_index == sel.end_track) and sel.end_column or total_columns_visible
          
          local track_columns = 0
          for line_index = sel.start_line, sel.end_line do
            local line = track:line(line_index)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if col > note_columns_visible and column_index > 0 and column_index <= effect_columns_visible then
                if EditStepCheckboxValue and (line_index - sel.start_line) % step ~= 0 then
                  -- Clear effect on this line if EditStep is enabled and line doesn't match
                  clear_effect_line(line, column_index)
                  print("  Skipping line " .. line_index .. " (EditStep) - clearing effect")
                else
                  -- Insert effect on this line
                  if write_effect_command then
                    line:effect_column(column_index).number_string = effect
                  end
                  line:effect_column(column_index).amount_string = arg_display
                  if write_effect_command then
                    print("  Set effect " .. effect .. arg_display .. " at track " .. song:track(track_index).name .. ", line " .. line_index .. ", column " .. column_index)
                  else
                    print("  Set effect argument " .. arg_display .. " at track " .. song:track(track_index).name .. ", line " .. line_index .. ", column " .. column_index)
                  end
                  effect_column_selected = true
                  -- Count each unique effect column only once per track
                  if line_index == sel.start_line then
                    track_columns = track_columns + 1
                  end
                end
              end
            end
          end
          if track_columns > 0 then
            affected_tracks[track_index] = track_columns
            total_columns = total_columns + track_columns
          end
        end
      end
    end
    
    if not effect_column_selected then
      print("  No effect columns found - effect not applied")
    else
      -- Create detailed status message
      local track_count = 0
      local min_track = nil
      local max_track = nil
      for track_index, _ in pairs(affected_tracks) do
        track_count = track_count + 1
        if min_track == nil or track_index < min_track then
          min_track = track_index
        end
        if max_track == nil or track_index > max_track then
          max_track = track_index
        end
      end
      
      local track_range = ""
      if track_count == 1 then
        track_range = "Track " .. min_track
      else
        track_range = "Tracks " .. min_track .. "-" .. max_track
      end
      
      if write_effect_command then
        renoise.app():show_status("Wrote Effect " .. effect .. " at value " .. arg_display .. " to " .. total_columns .. " Effect Columns on " .. track_range)
      else
        renoise.app():show_status("Wrote Effect argument " .. arg_display .. " to " .. total_columns .. " Effect Columns on " .. track_range)
      end
    end
    
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  local function pakettiPlayerProUpdateMainVolumeDisplay()
    local vol_display = main_volume_switch_group[1] .. main_volume_switch_group[2]
    main_vb.views["main_volume_display"].text = vol_display == "00" and "00" or vol_display
    
    -- Print detailed information when volume changes
    local song = renoise.song()
    local sel = song.selection_in_pattern
    local editstep_status = EditStepCheckboxValue and "ENABLED" or "DISABLED"
    local step = song.transport.edit_step
    
    print("=== MAIN DIALOG VOLUME CHANGED ===")
    print("Volume: " .. vol_display)
    print("EditStep: " .. editstep_status .. " (step size: " .. step .. ")")
    
    -- Check for valid track types first
    local start_track, end_track
    if sel then
      start_track = sel.start_track
      end_track = sel.end_track
    else
      start_track = song.selected_track_index
      end_track = song.selected_track_index
    end
    
    local is_valid_track = false
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        is_valid_track = true
        break
      end
    end

    if not is_valid_track then
      renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
      return
    end
    
    if sel then
      print("Selection:")
      print("  Tracks: " .. sel.start_track .. " to " .. sel.end_track)
      print("  Lines: " .. sel.start_line .. " to " .. sel.end_line)
      print("  Columns: " .. sel.start_column .. " to " .. sel.end_column)
      local total_lines = sel.end_line - sel.start_line + 1
      print("  Total lines: " .. total_lines)
      
      if EditStepCheckboxValue and step > 1 then
        local affected_lines = 0
        for line_index = sel.start_line, sel.end_line do
          if (line_index - sel.start_line) % step == 0 then
            affected_lines = affected_lines + 1
          end
        end
        print("  Lines that will be affected by EditStep: " .. affected_lines .. " out of " .. total_lines)
      end
    else
      print("No selection - single line/column:")
      print("  Track: " .. song.selected_track_index .. " (" .. song.selected_track.name .. ")")
      print("  Line: " .. song.selected_line_index)
      print("  Column: " .. song.selected_note_column_index)
    end
    print("=====================================")
    
    -- Actually write the volume to the pattern - removed condition that prevented "00"
    print("Writing volume " .. vol_display .. " to pattern...")
    
    local pattern_index = song.selected_pattern_index
    local note_column_selected = false
    
    if step == 0 then
      step = 1
    end
    
    local function insert_volume_line(line, col, track_idx, line_idx)
      line:note_column(col).volume_string = vol_display
      print("  Set volume " .. vol_display .. " at track " .. song:track(track_idx).name .. ", line " .. line_idx .. ", column " .. col)
    end
    
    local function clear_volume_line(line, col)
      line:note_column(col).volume_string = ".."
      print("  Clearing volume column on non-editstep row")
    end
    
    if sel == nil then
      local line = song.selected_line
      local col = song.selected_note_column_index
      local visible_note_columns = song.selected_track.visible_note_columns
      if col > 0 and col <= visible_note_columns then
        insert_volume_line(line, col, song.selected_track_index, song.selected_line_index)
        note_column_selected = true
      end
    else
      for track_index = sel.start_track, sel.end_track do
        local track = song:track(track_index)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local pattern_track = song.patterns[pattern_index]:track(track_index)
          local visible_note_columns = track.visible_note_columns
          
          for line_index = sel.start_line, sel.end_line do
            local line = pattern_track:line(line_index)
            for col_index = 1, visible_note_columns do
              if (track_index > sel.start_track) or (col_index >= sel.start_column) then
                if col_index <= visible_note_columns then
                  if EditStepCheckboxValue and (line_index - sel.start_line) % step ~= 0 then
                    -- Clear volume on this line if EditStep is enabled and line doesn't match
                    clear_volume_line(line, col_index)
                    print("  Skipping line " .. line_index .. " (EditStep) - clearing volume")
                  else
                    -- Insert volume on this line
                    insert_volume_line(line, col_index, track_index, line_index)
                    note_column_selected = true
                  end
                end
              end
            end
          end
        end
      end
    end
    
    if not note_column_selected then
      renoise.app():show_status("No note columns found - volume not applied")
    else
      -- Count the affected columns and tracks for better status message
      local affected_tracks = {}
      local total_columns = 0
      
      if sel == nil then
        affected_tracks[song.selected_track_index] = 1
        total_columns = 1
      else
        for track_index = sel.start_track, sel.end_track do
          local track = song:track(track_index)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local visible_note_columns = track.visible_note_columns
            local track_columns = 0
            for col_index = 1, visible_note_columns do
              if (track_index > sel.start_track) or (col_index >= sel.start_column) then
                track_columns = track_columns + 1
                total_columns = total_columns + 1
              end
            end
            if track_columns > 0 then
              affected_tracks[track_index] = track_columns
            end
          end
        end
      end
      
      local track_count = 0
      local min_track = nil
      local max_track = nil
      for track_index, _ in pairs(affected_tracks) do
        track_count = track_count + 1
        if min_track == nil or track_index < min_track then
          min_track = track_index
        end
        if max_track == nil or track_index > max_track then
          max_track = track_index
        end
      end
      
      local track_range = ""
      if track_count == 1 then
        track_range = "Track " .. min_track
      else
        track_range = "Tracks " .. min_track .. "-" .. max_track
      end
      
      renoise.app():show_status("Wrote Volume " .. vol_display .. " to " .. total_columns .. " Note Columns on " .. track_range)
    end
    
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  function pakettiPlayerProUpdateMainEffectArgumentDisplay()
    local arg_display = main_switch_group[1] .. main_switch_group[2]
    main_vb.views["main_effect_argument_display"].text = arg_display == "00" and "00" or arg_display
    
    -- Print detailed information when effect changes
    local song = renoise.song()
    local sel = song.selection_in_pattern
    local editstep_status = EditStepCheckboxValue and "ENABLED" or "DISABLED"
    local step = song.transport.edit_step
    
    print("=== MAIN DIALOG EFFECT CHANGED ===")
    print("Effect Argument: " .. arg_display)
    print("EditStep: " .. editstep_status .. " (step size: " .. step .. ")")
    
    -- Check for valid track types first
    local start_track, end_track
    if sel then
      start_track = sel.start_track
      end_track = sel.end_track
    else
      start_track = song.selected_track_index
      end_track = song.selected_track_index
    end
    
    local is_valid_track = false
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        is_valid_track = true
        break
      end
    end

    if not is_valid_track then
      renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Effect Columns. Doing nothing.")
      return
    end
    
    if sel then
      print("Selection:")
      print("  Tracks: " .. sel.start_track .. " to " .. sel.end_track)
      print("  Lines: " .. sel.start_line .. " to " .. sel.end_line)
      print("  Columns: " .. sel.start_column .. " to " .. sel.end_column)
      local total_lines = sel.end_line - sel.start_line + 1
      print("  Total lines: " .. total_lines)
      
      if EditStepCheckboxValue and step > 1 then
        local affected_lines = 0
        for line_index = sel.start_line, sel.end_line do
          if (line_index - sel.start_line) % step == 0 then
            affected_lines = affected_lines + 1
          end
        end
        print("  Lines that will be affected by EditStep: " .. affected_lines .. " out of " .. total_lines)
      end
    else
      print("No selection - single line/column:")
      print("  Track: " .. song.selected_track_index .. " (" .. song.selected_track.name .. ")")
      print("  Line: " .. song.selected_line_index)
      print("  Column: " .. song.selected_note_column_index)
    end
    print("=====================================")
    
    -- Actually write the effect to the pattern - removed condition that prevented "00"
    print("Writing effect argument " .. arg_display .. " to pattern...")
    
    -- Get the selected effect from the popup
    local effect = nil
    local effect_popup_value = main_vb.views["main_effect_popup"].value
    local write_effect_command = false
    
    if effect_popup_value > 1 then
      local effect_description = effect_items[effect_popup_value]
      -- Extract the effect code (e.g., "0A" from "0Axy - Arpeggio...")
      effect = string.match(effect_description, "^(%w%w)")
      write_effect_command = true
      print("Using effect: " .. effect)
    else
      print("Effect dropdown is 'None' - writing only effect argument values")
    end
    
    local pattern_index = song.selected_pattern_index
    local effect_column_selected = false
    
    if step == 0 then
      step = 1
    end
    
    local function insert_effect_line(line, col, track_idx, line_idx)
      if write_effect_command then
        line:effect_column(col).number_string = effect
      end
      line:effect_column(col).amount_string = arg_display
      if write_effect_command then
        print("  Set effect " .. effect .. arg_display .. " at track " .. song:track(track_idx).name .. ", line " .. line_idx .. ", column " .. col)
      else
        print("  Set effect argument " .. arg_display .. " at track " .. song:track(track_idx).name .. ", line " .. line_idx .. ", column " .. col)
      end
    end
    
    local function clear_effect_line(line, col)
      line:effect_column(col).number_string = ".."
      line:effect_column(col).amount_string = ".."
      print("  Clearing effect column on non-editstep row")
    end
    
    -- Count affected columns and tracks for status message
    local affected_tracks = {}
    local total_columns = 0
    
    if sel == nil then
      local line = song.selected_line
      local col = song.selected_effect_column_index
      if col > 0 and col <= song.selected_track.visible_effect_columns then
        insert_effect_line(line, col, song.selected_track_index, song.selected_line_index)
        effect_column_selected = true
        affected_tracks[song.selected_track_index] = 1
        total_columns = 1
      end
    else
      -- Use the same pattern as PakettiPatternEditorCheatSheet.lua
      for track_index = sel.start_track, sel.end_track do
        local track = song:pattern(pattern_index):track(track_index)
        local trackvis = song:track(track_index)
        if trackvis.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          local note_columns_visible = trackvis.visible_note_columns
          local effect_columns_visible = trackvis.visible_effect_columns
          local total_columns_visible = note_columns_visible + effect_columns_visible

          local start_column = (track_index == sel.start_track) and sel.start_column or 1
          local end_column = (track_index == sel.end_track) and sel.end_column or total_columns_visible
          
          local track_columns = 0
          for line_index = sel.start_line, sel.end_line do
            local line = track:line(line_index)
            for col = start_column, end_column do
              local column_index = col - note_columns_visible
              if col > note_columns_visible and column_index > 0 and column_index <= effect_columns_visible then
                if EditStepCheckboxValue and (line_index - sel.start_line) % step ~= 0 then
                  -- Clear effect on this line if EditStep is enabled and line doesn't match
                  clear_effect_line(line, column_index)
                  print("  Skipping line " .. line_index .. " (EditStep) - clearing effect")
                else
                  -- Insert effect on this line
                  if write_effect_command then
                    line:effect_column(column_index).number_string = effect
                  end
                  line:effect_column(column_index).amount_string = arg_display
                  if write_effect_command then
                    print("  Set effect " .. effect .. arg_display .. " at track " .. song:track(track_index).name .. ", line " .. line_index .. ", column " .. column_index)
                  else
                    print("  Set effect argument " .. arg_display .. " at track " .. song:track(track_index).name .. ", line " .. line_index .. ", column " .. column_index)
                  end
                  effect_column_selected = true
                  -- Count each unique effect column only once per track
                  if line_index == sel.start_line then
                    track_columns = track_columns + 1
                  end
                end
              end
            end
          end
          if track_columns > 0 then
            affected_tracks[track_index] = track_columns
            total_columns = total_columns + track_columns
          end
        end
      end
    end
    
    if not effect_column_selected then
      renoise.app():show_status("No effect columns found - effect not applied")
    else
      -- Create detailed status message
      local track_count = 0
      local min_track = nil
      local max_track = nil
      for track_index, _ in pairs(affected_tracks) do
        track_count = track_count + 1
        if min_track == nil or track_index < min_track then
          min_track = track_index
        end
        if max_track == nil or track_index > max_track then
          max_track = track_index
        end
      end
      
      local track_range = ""
      if track_count == 1 then
        track_range = "Track " .. min_track
      else
        track_range = "Tracks " .. min_track .. "-" .. max_track
      end
      
      if write_effect_command then
        renoise.app():show_status("Wrote Effect " .. effect .. " at value " .. arg_display .. " to " .. total_columns .. " Effect Columns on " .. track_range)
      else
        renoise.app():show_status("Wrote Effect argument " .. arg_display .. " to " .. total_columns .. " Effect Columns on " .. track_range)
      end
    end
    
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end

  local dialog_content = main_vb:column{
    --margin=10,
    main_vb:row{
      main_vb:text{
        text="Instrument", style="strong",font="bold",
      },
      main_vb:popup{
        items = instrument_items,
        width=320,
        id = "main_dialog_instrument_popup",
        value = selected_instrument_value,
        notifier=function(value)
          local instrument
          if value == 1 then
            instrument = nil
            renoise.song().selected_instrument_index = nil
          else
            instrument = value - 1
            renoise.song().selected_instrument_index = instrument
          end
          print("Main Dialog - Instrument changed to: " .. tostring(instrument))
        end
      },
      main_vb:button{
        text="Refresh",
        width=100,
        notifier=function()
          update_main_instrument_popup()
        end
      }
    },
    main_vb:row{
      pakettiPlayerProCreateMainNoteGrid(main_vb)
    },
    main_vb:row{
      main_vb:text{text="Effect", style="strong", font="bold"},
      main_vb:popup{
        items = effect_items,
        width=450,
        id = "main_effect_popup",
        notifier = function(value)
          pakettiPlayerProUpdateMainEffectDropdown()
        end
      }
    },
    main_vb:row{
        main_vb:column{
          main_vb:text{text="Volume", style="strong", font="bold"},
          pakettiPlayerProCreateMainVolumeColumn(1, main_volume_switch_group, pakettiPlayerProUpdateMainVolumeDisplay),
          pakettiPlayerProCreateMainVolumeColumn(2, main_volume_switch_group, pakettiPlayerProUpdateMainVolumeDisplay),
          main_vb:text{id = "main_volume_display", text="00",width=40, style="strong", font="bold"},
        },
        main_vb:column{},
        main_vb:column{
          main_vb:text{text="Effect", style="strong", font="bold"},
          pakettiPlayerProCreateMainArgumentColumn(1, main_switch_group, pakettiPlayerProUpdateMainEffectArgumentDisplay),
          pakettiPlayerProCreateMainArgumentColumn(2, main_switch_group, pakettiPlayerProUpdateMainEffectArgumentDisplay),
          main_vb:text{id = "main_effect_argument_display", text="00",width=40, style="strong", font="bold"},
      }
    },
    main_vb:row{
      --spacing=10,
      main_vb:button{
        text="Apply",
        width=100,
        notifier=function()
          local instrument_value = main_vb.views["main_dialog_instrument_popup"].value - 2
          local instrument = instrument_value >= 0 and instrument_value or nil
          
          -- Extract effect code from selected effect description
          local effect = nil
          local effect_popup_value = main_vb.views["main_effect_popup"].value
          if effect_popup_value > 1 then
            local effect_description = effect_items[effect_popup_value]
            -- Extract the effect code (e.g., "0A" from "0Axy - Arpeggio...")
            effect = string.match(effect_description, "^(%w%w)")
          end
          
          local effect_argument = main_vb.views["main_effect_argument_display"].text
          local volume = main_vb.views["main_volume_display"].text
          -- Insert all selected values
          pakettiPlayerProMainDialogInsertNoteInPattern(nil, instrument, effect, effect_argument, volume, EditStepCheckboxValue)
          -- Return focus to the Pattern Editor
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      main_vb:button{
        text="Cancel",
        width=100,
        notifier=function()
          -- Clean up observer before closing
          if main_dialog_instrument_observer then
            PakettiPlayerProRemoveInstrumentObserver(main_dialog_instrument_observer)
            main_dialog_instrument_observer = nil
          end
          dialog:close()
          -- Clean up references
          dialog = nil
        end
      }
    }
  }

  dialog = renoise.app():show_custom_dialog("Player Pro Main Dialog", dialog_content, my_keyhandler_func)
  
  -- Add instrument observer after dialog is created
  main_dialog_instrument_observer = PakettiPlayerProCreateInstrumentObserver(main_vb, "main_dialog_instrument_popup", dialog)
  
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Open Player Pro Tools Dialog...",invoke=pakettiPlayerProShowMainDialog}

function pakettiPlayerProMainDialogInsertNoteInPattern(note, instrument, effect, effect_argument, volume, editstep_enabled)
  local song=renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local note_column_selected = false
  local step = song.transport.edit_step

  if step == 0 then
    step = 1
  end

  -- Check for valid track types first
  local start_track, end_track
  if sel then
    start_track = sel.start_track
    end_track = sel.end_track
  else
    start_track = song.selected_track_index
    end_track = song.selected_track_index
  end
  
  local is_valid_track = false
  for track_index = start_track, end_track do
    local track = song:track(track_index)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      is_valid_track = true
      break
    end
  end

  if not is_valid_track then
    renoise.app():show_status("The selected track is a Group / Master or Send, and doesn't have Note Columns. Doing nothing.")
    return
  end

  -- Only print debug info if we have valid tracks
  print("Inserted: " .. note .. " with EditStep: " .. tostring(editstep_enabled) .. ", Volume: " .. volume .. ", Effect: " .. tostring(effect))

  local function insert_note_line(line, col)
    if note then
      line:note_column(col).note_string = note_to_insert
    end
    
    if note == "OFF" or note == "---" or note == "000" then
      line:note_column(col).instrument_string = ".." 
    end

    if instrument ~= nil and note ~= "000" and note ~= "OFF" then
      local instrument_actual = instrument - 1
      local instrument_string = string.format("%02X", instrument_actual)
      line:note_column(col).instrument_string = instrument_string
    end
    
    if effect and effect ~= "None" and note ~= "---" and note ~= "OFF" then
      line:effect_column(col).number_string = effect
      line:effect_column(col).amount_string = effect_argument ~= "00" and effect_argument or "00"
    end
    
    if volume and volume ~= "00" and note ~= "---" and note ~= "OFF" then
      line:note_column(col).volume_string = volume
    end
    
  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

  local function clear_note_line(line, col)
    line:note_column(col).note_string = "---"
    line:note_column(col).instrument_string = ".."
    line:note_column(col).volume_string = ".."
    print("Clearing note column and volume on non-editstep row")
  end

  if sel == nil then
    local line = song.selected_line
    local col = song.selected_note_column_index
    local visible_note_columns = song.selected_track.visible_note_columns
    if col > 0 and col <= visible_note_columns then
      insert_note_line(line, col)
      note_column_selected = true
    end
  else
    for track_index = sel.start_track, sel.end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        local pattern_track = song.patterns[pattern_index]:track(track_index)
        local visible_note_columns = track.visible_note_columns

        for line_index = sel.start_line, sel.end_line do
          local line = pattern_track:line(line_index)
          for col_index = 1, visible_note_columns do
            if (track_index > sel.start_track) or (col_index >= sel.start_column) then
              if col_index <= visible_note_columns then
                if editstep_enabled and (line_index - sel.start_line) % step ~= 0 then
                  -- Clear effect on this line if EditStep is enabled and line doesn't match
                  clear_note_line(line, col_index)
                else
                  -- Otherwise, insert the note with effects and volume
                  insert_note_line(line, col_index)
                  note_column_selected = true
                end
              end
            end
          end
        end
      end
    end
  end

  if not note_column_selected then
    renoise.app():show_status("No Note Columns were selected, doing nothing.")
  end
end  

-- MIDI Mapping for Player Pro Effect Lower Value (0-127 maps to 0-F)
renoise.tool():add_midi_mapping{name="Paketti:Player Pro Effect Lower Value x[Knob]",
  invoke=function(message)
    print("=== MIDI MAPPING TRIGGERED ===")
    print("MIDI message received")
    print("Is abs value: " .. tostring(message:is_abs_value()))
    print("MIDI value: " .. tostring(message.int_value))
    
    if message:is_abs_value() then
      -- Check if main dialog is open and has the required views
      if dialog and dialog.visible and main_vb and main_vb.views["main_effect_argument_display"] then
        print("Dialog is open and views are available")
        
        -- Map MIDI value 0-127 to hex value 0-15 (0-F)
        local hex_value = math.floor((message.int_value / 127) * 15)
        local hex_string = string.format("%X", hex_value)
        
        print("MIDI " .. message.int_value .. " mapped to hex " .. hex_value .. " (" .. hex_string .. ")")
        
        -- Update the lower effect value (second digit)
        local old_value = main_switch_group[2]
        main_switch_group[2] = hex_string
        print("Updated main_switch_group[2] from '" .. old_value .. "' to '" .. hex_string .. "'")
        
        -- Update the display
        local combined = main_switch_group[1] .. main_switch_group[2]
        print("Combined effect argument: " .. combined)
        
        -- Update the display text directly
        main_vb.views["main_effect_argument_display"].text = combined
        print("Updated display text to: " .. combined)
        
        -- Update the actual switch control (column 2) to show the correct selection
        -- Switch uses 1-based indexing: hex 0=index 1, hex 1=index 2, ..., hex F=index 16
        local switch_index = hex_value + 1
        local switch_control = main_vb.views["main_effect_lower_switch"]
        if switch_control then
          switch_control.value = switch_index
          print("Updated switch control to index " .. switch_index .. " for hex " .. hex_string)
        else
          print("Could not find switch control 'main_effect_lower_switch'")
        end
        
        -- Show status
        renoise.app():show_status("Player Pro Effect Lower Value: " .. hex_string)
        print("Status updated: Player Pro Effect Lower Value: " .. hex_string)
      else
        print("Dialog not available - dialog: " .. tostring(dialog) .. ", visible: " .. tostring(dialog and dialog.visible) .. ", main_vb: " .. tostring(main_vb))
        renoise.app():show_status("Player Pro Main Dialog is not open")
      end
    else
      print("Message is not absolute value, ignoring")
    end
    print("=== MIDI MAPPING END ===")
  end
}
