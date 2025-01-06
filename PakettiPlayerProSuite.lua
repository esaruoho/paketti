local vb=renoise.ViewBuilder()
local column2=vb:column{style="group"}
local column3=vb:column{style="group"}
local hex_text2=vb:text{text="0", style="normal"}
local hex_text3=vb:text{text="0", style="normal"}
local combined_text1=vb:text{text="00", style="strong", font="bold"}
local value_labels2={}
local value_labels3={}
local label_map2 = {}
local label_map3 = {}
local writing_enabled = false

local function update_combined_value()
  local combined_value=hex_text3.text..hex_text2.text
  combined_text1.text=combined_value
  renoise.app():show_status(combined_text1.text)

  if not renoise.song() or not writing_enabled then return end

  local song = renoise.song()
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
  local number_label=vb:text{text=hex, width=2,style="normal"}
  label_map[label_id] = number_label
  value_labels[#value_labels + 1] = number_label
  
  local valuebox=vb:valuebox{
    value=i,min=i,max=i,width=8,
    tostring=function(v)
      local hex_value=string.format("%X",v)
      hex_text.text=hex_value
      update_combined_value()
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

local dialog_content=vb:column{
  margin=10,
  vb:row{
    vb:checkbox{
      value = writing_enabled,
      notifier = function(val)
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
    vb:row{combined_text1}
  }
}

local function my_PPEffectkeyhandler_func(dialog, key)
  -- Check for specific keys to handle in the dialog
  local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
dialog:close()
dialog=nil
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR

return nil
else
  return key
end
end

--renoise.app():show_custom_dialog("FX", dialog_content)
renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti..:Other Trackers..:Open Player Pro Tools Effect Dialog", invoke = function() renoise.app():show_custom_dialog("FX", dialog_content, my_PPEffectkeyhandler_func) 
renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end}
---------------

local vb
local dialog

local note_names = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
local notes = {}
for octave = 0, 9 do
  for _, note in ipairs(note_names) do
    table.insert(notes, note .. octave)
  end
end
table.insert(notes, "000") -- Adding "---" as "000"
table.insert(notes, "OFF")

local function PakettiPlayerProNoteGridInsertNoteInPattern(note, instrument, editstep)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local note_column_selected = false
  local step = song.transport.edit_step -- Get the current edit step value from the transport
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
    print("Clearing note column on non-editstep row")
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
      local pattern_track = song.patterns[pattern_index]:track(track_index)
      local visible_note_columns = song:track(track_index).visible_note_columns
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

  if not note_column_selected then
    local message = "No Note Columns were selected, doing nothing."
    renoise.app():show_status(message)
  end
end

local function PakettiPlayerProNoteGridUpdateInstrumentInPattern(instrument, editstep_enabled)
  local song = renoise.song()
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
  if vb.views["instrument_popup"] then
    vb.views["instrument_popup"].items = instrument_items
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


function PakettiPlayerProNoteGridCreateGrid()
  local grid_rows = 11
  local grid_columns = 12
  local grid = vb:column{}

  -- Add the checkbox at the top of the grid
  grid:add_child(vb:row{
    vb:checkbox{
      value = EditStepCheckboxValue, -- Initialize checkbox
      notifier = function(value)
        EditStepCheckboxValue = value -- Update the shared value
      end
    },
    vb:text{
      text = "Fill Selection with EditStep", style="strong",font="bold"
    }
  })

  -- Create the grid of note buttons
  for row = 1, grid_rows do
    local row_items = vb:row{}
    for col = 1, grid_columns do
      local index = (row - 1) * grid_columns + col
      if notes[index] then
        -- Add a button for each note in the grid
        row_items:add_child(vb:button{
          text = notes[index],
          width = 30,
          height = 15,
          notifier = function()
            local instrument_value = renoise.song().selected_instrument_index
            print("Note button clicked. Instrument Value: " .. tostring(instrument_value))

            -- Pass the note, instrument, and EditStepCheckboxValue to the insert function
            PakettiPlayerProNoteGridInsertNoteInPattern(notes[index], instrument_value, EditStepCheckboxValue)

            -- Return focus to the Pattern Editor
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        })
      end
    end
    grid:add_child(row_items)
  end

  return grid
end


local function PakettiPlayerProNoteGridCloseDialog()
  if dialog and dialog.visible then
    dialog:close()
  end
  dialog = nil
  print("Dialog closed.")
  renoise.app():show_status("Closing Paketti PlayerPro Note Dialog")
end


local function PakettiPlayerProNoteGridCreateDialogContent()
  vb = renoise.ViewBuilder()
local EditStepCheckboxValue = false -- Initial value for EditStepCheckbox

  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end

  local selected_instrument_index = renoise.song().selected_instrument_index
  local selected_instrument_value = selected_instrument_index + 1
  print("Dialog opened. Selected Instrument Index: " .. tostring(selected_instrument_index) .. ", Selected Instrument Value: " .. tostring(selected_instrument_value))

  return vb:column{
    margin = 10,
    width="100%",
    vb:row{
      vb:text{
        text = "Instrument:",style="strong",font="bold"
      },
      vb:popup{
        items = instrument_items,
        width = 220,
        id = "instrument_popup",
        value = selected_instrument_value,
        notifier = function(value)
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
      vb:button{
        text = "Refresh",
        width = 90,
        notifier = function()
          PakettiPlayerProNoteGridUpdateInstrumentPopup()
        end
      }
    },
     PakettiPlayerProNoteGridCreateGrid(),
    vb:row{
      vb:button{
        text = "Close",
        width = 381,
        notifier = function()
          PakettiPlayerProNoteGridCloseDialog()
        end
      }
    }
  }
end


local function PakettiPlayerProNoteGridKeyHandlerFunc(dialog, key)

local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
dialog:close()
dialog=nil
return nil
else
  end
end

local function PakettiPlayerProNoteGridShowDropdownGrid()
renoise.app().window.active_middle_frame=1

  if dialog and dialog.visible then
    print("Dialog is visible, closing dialog.")
    PakettiPlayerProNoteGridCloseDialog()
  else
    print("Dialog is not visible, creating new dialog.")
    dialog = renoise.app():show_custom_dialog("Player Pro Note Selector with EditStep", PakettiPlayerProNoteGridCreateDialogContent(), --PakettiPlayerProNoteGridKeyHandlerFunc)
 my_PPEffectkeyhandler_func)
    print("Dialog opened.")
    renoise.app():show_status("Opening Paketti PlayerPro Note Dialog")
    -- Return focus to the Pattern Editor
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end
end

local function PakettiPlayerProNoteGridAddNoteMenuEntries()
  local note_ranges = {
    {name = "C-0 to B-2", range_start = 1, range_end = 36},
    {name = "C-3 to B-5", range_start = 37, range_end = 72},
    {name = "C-6 to B-9", range_start = 73, range_end = 108}
  }

  for _, range in ipairs(note_ranges) do
    for i = range.range_start, range.range_end do
      if notes[i] then
        renoise.tool():add_menu_entry{
          name = "Pattern Editor:Paketti..:Other Trackers..:Note Dropdown.."..range.name..":"..notes[i],
          invoke = function() PakettiPlayerProNoteGridInsertNoteInPattern(notes[i], renoise.song().selected_instrument_index) end}
      end
    end
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Note Dropdown.."..range.name..":000", invoke=function() PakettiPlayerProNoteGridInsertNoteInPattern("000", renoise.song().selected_instrument_index) end}
    renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Note Dropdown.."..range.name..":OFF", invoke=function() PakettiPlayerProNoteGridInsertNoteInPattern("OFF", renoise.song().selected_instrument_index) end}
  end
end

-- Handle scenario when the dialog is closed by other means
renoise.app().window.active_middle_frame_observable:add_notifier(function()
  if dialog and not dialog.visible then
    print("Dialog is not visible, removing reference.")
    PakettiPlayerProNoteGridCloseDialog()
    print("Reference removed.")
  end
end)

renoise.tool():add_menu_entry{name="Pattern Editor:Paketti..:Other Trackers..:Open Player Pro Note Column Dialog", invoke=PakettiPlayerProNoteGridShowDropdownGrid}
renoise.tool():add_keybinding{name="Global:Paketti:Open Player Pro Note Column Dialog", invoke=PakettiPlayerProNoteGridShowDropdownGrid}

PakettiPlayerProNoteGridAddNoteMenuEntries()
--------------







-- Function to transpose notes
function pakettiPlayerProTranspose(steps)
  local song = renoise.song()
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
    start_column = 1
    end_column = song.tracks[start_track].visible_note_columns
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
end

-- Adding keybindings for PlayerPro Transpose
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +1",invoke=function() pakettiPlayerProTranspose(1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -1",invoke=function() pakettiPlayerProTranspose(-1) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row +12",invoke=function() pakettiPlayerProTranspose(12) end}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Transpose Selection or Row -12",invoke=function() pakettiPlayerProTranspose(-12) end}

--------------------

local vb = renoise.ViewBuilder()
local dialog

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

local effect_descriptions = {
  "0Axy - Arpeggio (x=base note offset1, y=base note offset 2) *",
  "0Uxx - Pitch Slide up (00-FF) *",
  "0Dxx - Pitch Slide down (00-FF) *",
  "0Mxx - Set Channel volume (00-FF)",
  "0Cxy - Volume slicer -- x=factor (0=0.0, F=1.0), slice at tick y. *",
  "0Gxx - Glide to note with step xx (00-FF)*",
  "0Ixx - Volume Slide Up with step xx (00-64) (64x0601 or 2x0632 = slide0-full) *",
  "0Oxx - Volume Slide Down with step xx (00-64) *",
  "0Pxx - Set Panning (00-FF) (00: left; 80: center; FF: right)",
  "0Sxx - Trigger Sample Offset, 00 is sample start, FF is sample end. *",
  "0Wxx - Surround Width (00-FF) *",
  "0Bxx - Play Sample Backwards (B00) or forwards again (B01) *",
  "0Lxx - Set track-Volume (00-FF)",
  "0Qxx - Delay notes in track-row xx ticks before playing. (00-speed)",
  "0Rxy - Retrig notes in track-row every xy ticks (x=volume; y=ticks 0 - speed) **",
  "0Vxy - Set Vibrato x= speed, y= depth; x=(0-F); y=(0-F)*",
  "0Txy - Set Tremolo x= speed, y= depth",
  "0Nxy - Set Auto Pan, x= speed, y= depth",
  "0Exx - Set Active Sample Envelope's Position to Offset XX",
  "0Jxx - Set Track's Output Routing to channel XX",
  "0Xxx - Stop all notes and FX (xx = 00), or only effect xx (xx > 00)"
}

local function update_instrument_popup()
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02d: %s", i, (instrument.name or "Untitled")))
  end
  if vb.views["instrument_popup"] then
    vb.views["instrument_popup"].items = instrument_items
  end
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
  local song = renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local note_column_selected = false

  -- Debug logs
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
      local pattern_track = song.patterns[pattern_index]:track(track_index)
      local visible_note_columns = song:track(track_index).visible_note_columns
      for line_index = sel.start_line, sel.end_line do
        local line = pattern_track:line(line_index)
        for col_index = 1, renoise.song().tracks[track_index].visible_note_columns do
          if (track_index > sel.start_track) or (col_index >= sel.start_column) then
            if col_index <= visible_note_columns then
              pakettiPlayerProInsertIntoLine(line, col_index, note_to_insert, instrument, effect, effect_argument, volume)
              note_column_selected = true
              print("Inserted note (" .. (note_to_insert or "N/A") .. ") at track " .. track_index .. " (" .. song:track(track_index).name .. "), line " .. line_index .. ", column " .. col_index)
            end
          end
        end
      end
    end
  end

  if not note_column_selected then
    local message = "No Note Columns were selected, doing nothing."
    print(message)
    renoise.app():show_status(message)
  end
end

local function pakettiPlayerProCreateNoteGrid()
  local grid_rows = 11
  local grid_columns = 12
  local grid = vb:column{}
  for row = 1, grid_rows do
    local row_items = vb:row{}
    for col = 1, grid_columns do
      local index = (row - 1) * grid_columns + col
      if notes[index] then
        row_items:add_child(vb:button{
          text = notes[index],
          width = 30,
          height = 15,
          notifier = function()
            local instrument_value = vb.views["instrument_popup"].value - 2
            local instrument = instrument_value >= 0 and instrument_value or nil
            local effect = vb.views["effect_popup"].value > 1 and vb.views["effect_popup"].items[vb.views["effect_popup"].value] or nil
            local effect_argument = vb.views["effect_argument_display"].text
            local volume = vb.views["volume_display"].text
            pakettiPlayerProInsertNoteInPattern(notes[index], instrument, effect, effect_argument, volume)
            print("Inserted: " .. notes[index])
            -- Return focus to the Pattern Editor
            renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        })
      end
    end
    grid:add_child(row_items)
  end
  return grid
end

local function pakettiPlayerProCreateArgumentColumn(column_index, switch_group, update_display)
  return vb:switch{
    items = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"},
    width = 170,
    height = 20,
    value = 1, -- default to "Off"
    notifier = function(idx)
      switch_group[column_index] = idx == 1 and "0" or string.format("%X", idx - 1)
      update_display()
    end
  }
end

local function pakettiPlayerProUpdateEffectArgumentDisplay()
  local arg_display = switch_group[1] .. switch_group[2]
  vb.views["effect_argument_display"].text = arg_display == "00" and "00" or arg_display
end

local function pakettiPlayerProUpdateVolumeDisplay()
  local vol_display = volume_switch_group[1] .. volume_switch_group[2]
  vb.views["volume_display"].text = vol_display == "00" and "00" or vol_display
end

local function pakettiPlayerProShowMainDialog()
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02d: %s", i, (instrument.name or "Untitled")))
  end

  local dialog_content = vb:column{
    margin = 10,
    vb:row{
      vb:text{
        text = "Instrument:"
      },
      vb:popup{
        items = instrument_items,
        width = 218,
        id = "instrument_popup"
      },
      vb:button{
        text = "Refresh",
        width = 100,
        notifier = function()
          update_instrument_popup()
        end
      }
    },
    vb:row{
      pakettiPlayerProCreateNoteGrid()
    },
    vb:row{
      vb:text{
        text = "Effect:"
      },
      vb:popup{
        items = {"None", "Effect 1", "Effect 2", "Effect 3"}, -- Add actual effects here
        width = 200,
        id = "effect_popup"
      }
    },
    vb:row{
        vb:column{
          vb:text{text = "Volume"},
          pakettiPlayerProCreateArgumentColumn(1, volume_switch_group, pakettiPlayerProUpdateVolumeDisplay),
          pakettiPlayerProCreateArgumentColumn(2, volume_switch_group, pakettiPlayerProUpdateVolumeDisplay),
          vb:text{id = "volume_display", text = "00", width = 40, style="strong", font="bold"},
        },
        vb:column{},
        vb:column{
          vb:text{text = "Effect"},
          pakettiPlayerProCreateArgumentColumn(1, switch_group, pakettiPlayerProUpdateEffectArgumentDisplay),
          pakettiPlayerProCreateArgumentColumn(2, switch_group, pakettiPlayerProUpdateEffectArgumentDisplay),
          vb:text{id = "effect_argument_display", text = "00", width = 40, style="strong", font="bold"},
      }
    },
    vb:row{
      spacing = 10,
      vb:button{
        text = "Apply",
        width = 100,
        notifier = function()
          local instrument_value = vb.views["instrument_popup"].value - 2
          local instrument = instrument_value >= 0 and instrument_value or nil
          local effect_value = vb.views["effect_popup"].value
          local effect = effect_value > 1 and vb.views["effect_popup"].items[effect_value] or nil
          local effect_argument = vb.views["effect_argument_display"].text
          local volume = vb.views["volume_display"].text
          -- Insert all selected values
          pakettiPlayerProInsertNoteInPattern(nil, instrument, effect, effect_argument, volume)
          -- Return focus to the Pattern Editor
          renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text = "Cancel",
        width = 100,
        notifier = function()
          dialog:close()
        end
      }
    }
  }

  local function my_PPkeyhandler_func(dialog, key)
  
local closer = preferences.pakettiDialogClose.value
  if key.modifiers == "" and key.name == closer then
dialog:close()
dialog=nil
return nil
else

    return key
  end
end
  dialog = renoise.app():show_custom_dialog("Player Pro Main Dialog", dialog_content, my_PPkeyhandler_func)
end

renoise.tool():add_menu_entry{name = "Pattern Editor:Paketti..:Other Trackers..:Open Player Pro Tools Dialog...", invoke = pakettiPlayerProShowMainDialog}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Open Player Pro Tools Dialog...", invoke = pakettiPlayerProShowMainDialog}
