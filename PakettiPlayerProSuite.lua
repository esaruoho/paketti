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
local dialog_initializing = true  -- Flag to prevent excessive status updates during initialization

-- Experimental playback for transposed notes
local experimentalPlay = false
local pakettiPlayerPro_playing_notes = {}
local pakettiPlayerPro_current_timer = nil
local pakettiPlayerPro_playing_track = nil
local pakettiPlayerPro_playing_instrument = nil

local function update_combined_value()
  local combined_value=hex_text3.text..hex_text2.text
  combined_text1.text=combined_value
  
  -- Convert hex to decimal
  local decimal_value = tonumber(combined_value, 16)
  decimal_text.text = tostring(decimal_value)
  
  -- Only show status if not initializing to prevent excessive updates
  if not dialog_initializing then
    renoise.app():show_status(combined_text1.text .. " " .. decimal_value)
  end

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
local dialog
local note_grid_instrument_observer
local canvas_instrument_observer
local main_canvas_instrument_observer

local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
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

    end

    if instrument ~= nil and note ~= "000" and note ~= "OFF" then
      local instrument_actual = instrument - 1
      local instrument_string = string.format("%02X", instrument_actual)

      line:note_column(col).instrument_string = instrument_string
    end

    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
  else
    -- Show current note column status after insertion
    show_current_status()
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
            renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
  if dialog and dialog.visible then
    dialog:close()
  end
  
  -- Clean up instrument observer
  if note_grid_instrument_observer then
    PakettiPlayerProRemoveInstrumentObserver(note_grid_instrument_observer)
    note_grid_instrument_observer = nil
  end
  
  dialog = nil
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
  -- Smart dialog selection based on current context
  local song = renoise.song()
  
  -- Rule 1: If selection exists, always open note dialog
  if song.selection_in_pattern then
    -- Check API version - use canvas version for v6.2+, traditional for older
    if renoise.API_VERSION >= 6.2 then
      pakettiPlayerProNoteGridShowCanvasGrid()
    else
      pakettiPlayerProNoteGridShowTraditionalGrid()
    end
    return
  end
  
  -- Rule 2: No selection - check current column context
  local selected_track = song.selected_track
  if selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
    -- Rule 3: If in effect column, open effect dialog
    if song.selected_effect_column_index > 0 then
      pakettiPlayerProEffectDialog()
      return
    end
    
    -- Rule 4: If in note column, check subcolumn context (if preference enabled)
    if preferences.pakettiPlayerProSmartSubColumn and preferences.pakettiPlayerProSmartSubColumn.value then
      local sub_column_type = song.selected_sub_column_type
      -- Check if we're in a non-note subcolumn
      if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME or
         sub_column_type == renoise.Song.SUB_COLUMN_PANNING or
         sub_column_type == renoise.Song.SUB_COLUMN_DELAY or
         sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or
         sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
        pakettiPlayerProEffectDialog()
        return
      end
    end
  end
  
  -- Default: Open note dialog
  if renoise.API_VERSION >= 6.2 then
    pakettiPlayerProNoteGridShowCanvasGrid()
  else
    pakettiPlayerProNoteGridShowTraditionalGrid()
  end
end

function pakettiPlayerProNoteGridShowTraditionalGrid()
renoise.app().window.active_middle_frame=1

  if dialog and dialog.visible then
    print("Dialog is visible, closing dialog.")
    dialog:close()
    dialog=nil
    --PakettiPlayerProNoteGridCloseDialog()
  else
    print("Dialog is not visible, creating new dialog.")
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Player Pro Note Selector with EditStep", PakettiPlayerProNoteGridCreateDialogContent(),keyhandler)
    
    -- Add instrument observer after dialog is created
    note_grid_instrument_observer = PakettiPlayerProCreateInstrumentObserver(note_grid_vb, "note_grid_instrument_popup", dialog)
    
    print("Dialog opened.")
      show_current_status()
  -- Return focus to the Pattern Editor
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
  if dialog and not dialog.visible then
    print("Dialog is not visible, removing reference.")
    PakettiPlayerProNoteGridCloseDialog()
    print("Reference removed.")
  end
end)

renoise.tool():add_keybinding{name="Global:Paketti:Open Player Pro Note Column Dialog...",invoke=pakettiPlayerProNoteGridShowDropdownGrid}
renoise.tool():add_keybinding{name="Global:Paketti:Player Pro Intelligent Dialog...",invoke=pakettiPlayerProNoteGridShowDropdownGrid}

PakettiPlayerProNoteGridAddNoteMenuEntries()

-- Stop any currently playing experimental notes
function pakettiPlayerProStopPlayingNotes()
  if #pakettiPlayerPro_playing_notes == 0 then return end
  
  local song = renoise.song()
  if pakettiPlayerPro_playing_track and pakettiPlayerPro_playing_instrument then
    -- Remove duplicates from playing notes before triggering note_off
    local unique_notes = {}
    local note_set = {}
    for i = 1, #pakettiPlayerPro_playing_notes do
      local note = pakettiPlayerPro_playing_notes[i]
      if not note_set[note] then
        note_set[note] = true
        table.insert(unique_notes, note)
      end
    end
    
    if #unique_notes > 0 then
      song:trigger_instrument_note_off(pakettiPlayerPro_playing_instrument, pakettiPlayerPro_playing_track, unique_notes)
    end
  end
  
  -- Clear the timer if it exists
  if pakettiPlayerPro_current_timer then
    pakettiPlayerPro_current_timer = nil
  end
  
  -- Clear the arrays
  pakettiPlayerPro_playing_notes = {}
  pakettiPlayerPro_playing_track = nil
  pakettiPlayerPro_playing_instrument = nil
end

-- Play transposed notes for experimental feedback with sequential timing
function pakettiPlayerProPlayTransposedNotes(transposed_notes)
  if not experimentalPlay then return end
  
  local song = renoise.song()
  if not song.transport.playing then return end
  
  -- Stop any currently playing notes first
  pakettiPlayerProStopPlayingNotes()
  
  local track = song.selected_track
  if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return end
  
  local selected_track_index = song.selected_track_index
  local selected_instrument_index = song.selected_instrument_index
  local instrument = song:instrument(selected_instrument_index)
  
  if not instrument then return end
  
  if #transposed_notes == 0 then return end
  
  -- Group notes by line for sequential playback
  local notes_by_line = {}
  local min_line = nil
  
  for i = 1, #transposed_notes do
    local note_data = transposed_notes[i]
    if note_data.note and note_data.note >= 0 and note_data.note <= 119 then
      local line = note_data.line
      if not notes_by_line[line] then
        notes_by_line[line] = {}
      end
      table.insert(notes_by_line[line], note_data.note)
      
      -- Track the minimum line for timing calculation
      if not min_line or line < min_line then
        min_line = line
      end
    end
  end
  
  -- Calculate timing based on Renoise's tempo
  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local ms_per_line = (60000 / bpm) / lpb
  
  -- Store track and instrument for note-off
  pakettiPlayerPro_playing_track = selected_track_index
  pakettiPlayerPro_playing_instrument = selected_instrument_index
  
  -- Schedule notes to be played sequentially
  for line, notes in pairs(notes_by_line) do
    local delay = (line - min_line) * ms_per_line
    
    -- Remove duplicates from notes on this line
    local unique_notes = {}
    local note_set = {}
    for j = 1, #notes do
      if not note_set[notes[j]] then
        note_set[notes[j]] = true
        table.insert(unique_notes, notes[j])
      end
    end
    
    if #unique_notes > 0 then
      renoise.tool():add_timer(function()
        -- Add notes to playing notes list for cleanup
        for k = 1, #unique_notes do
          table.insert(pakettiPlayerPro_playing_notes, unique_notes[k])
        end
        
        -- Trigger notes on this line
        song:trigger_instrument_note_on(selected_instrument_index, selected_track_index, unique_notes, 1.0)
      end, math.max(1, math.floor(delay)))
    end
  end
  
  -- Set up cleanup timer to stop all notes after the sequence plus some sustain
  local total_duration = 0
  for line in pairs(notes_by_line) do
    local line_time = (line - min_line) * ms_per_line
    if line_time > total_duration then
      total_duration = line_time
    end
  end
  
  pakettiPlayerPro_current_timer = renoise.tool():add_timer(pakettiPlayerProStopPlayingNotes, math.max(1000, total_duration + 500))
end

--------------
function pakettiPlayerProTranspose(steps, range, playback)
  local song=renoise.song()
  local selection = song.selection_in_pattern
  local pattern = song.selected_pattern

  -- Determine the range to transpose
  local start_track, end_track, start_line, end_line, start_column, end_column
  
  -- For experimental playback, collect transposed notes with timing info
  local transposed_notes = {}

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
    local first_column, last_column
    local max_columns = math.min(12, tracks.visible_note_columns)
    
    if start_track == end_track then
      -- Single track selection: use exact column range but clamp to available columns
      first_column = math.max(1, math.min(start_column, max_columns))
      last_column = math.max(1, math.min(end_column, max_columns))
    else
      -- Multi-track selection: handle edge tracks differently than middle tracks
      if track_index == start_track then
        first_column = math.max(1, math.min(start_column, max_columns))
        last_column = max_columns
      elseif track_index == end_track then
        first_column = 1
        last_column = math.max(1, math.min(end_column, max_columns))
      else
        -- Middle tracks: use all visible columns
        first_column = 1
        last_column = max_columns
      end
    end

    -- Iterate through each line in the determined range
    for line_index = start_line, end_line do
      local line = track:line(line_index)

      -- Iterate through each note column in the line within the selected range
      for column_index = first_column, last_column do
        local note_column = line:note_column(column_index)
        if not note_column.is_empty then
          -- Skip transposing if note_value is 120 or 121
          if note_column.note_value < 120 then
            local new_note_value = (note_column.note_value + steps) % 120
            note_column.note_value = new_note_value
            
            -- Collect transposed note for experimental playback with timing info
            if experimentalPlay and song.transport.playing then
              table.insert(transposed_notes, {
                note = new_note_value,
                line = line_index,
                track = track_index,
                column = column_index
              })
            end
          end
        end
      end
    end
  end
  
  -- If playback is enabled, trigger the current line
  if playback then
    if song.transport.playing then
      renoise.app():show_status("Transpose & Play Line will only work if Playback is stopped, doing nothing.")
    else
      song:trigger_pattern_line(song.selected_line_index)
    end
  end
  
  -- Experimental playback: play transposed notes if transport is playing
  if experimentalPlay and song.transport.playing and #transposed_notes > 0 then
    pakettiPlayerProPlayTransposedNotes(transposed_notes)
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
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Player Pro Effect Dialog...",invoke=function() pakettiPlayerProEffectDialog() end}

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

local note_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
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
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    end
  }
  
  return PakettiPlayerProCreateModularNoteGrid(main_vb, config)
end

-- Global dialog variable for effect dialog
local effect_dialog = nil

function pakettiPlayerProEffectDialog()
  if effect_dialog and effect_dialog.visible then
    effect_dialog:close()
    effect_dialog = nil
    return
  end
  
  -- Check API version - use canvas version for v6.2+, traditional for older
  if renoise.API_VERSION >= 6.2 then
    pakettiPlayerProEffectDialogCanvas()
  else
    pakettiPlayerProEffectDialogTraditional()
  end
end

function pakettiPlayerProEffectDialogTraditional()
  dialog_initializing = true  -- Set flag before dialog creation
  local keyhandler = create_keyhandler_for_dialog(
    function() return effect_dialog end,
    function(value) effect_dialog = value end
  )
  effect_dialog = renoise.app():show_custom_dialog("FX", dialog_content, keyhandler)
  dialog_initializing = false  -- Clear flag after dialog is created
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Canvas-based Effect Hover Dialog for Renoise v6.2+
local effect_canvas_dialog = nil
local effect_canvas = nil
local canvas_width = 44
local canvas_height = 296
local cell_width = 18
local cell_height = 18
local left_column_x = 2
local right_column_x = 22
local column_start_y = 3
local hover_column = nil  -- "left" or "right"
local hover_index = -1    -- 0-15
local selected_x = 0      -- Left column (0-F)
local selected_y = 0      -- Right column (0-F)
local effect_status_text = nil
local should_grey_right_column_high_values = false  -- Flag for greying 9-F in right column
local previous_selected_y = 0  -- Memory for restoring col2 when returning from restricted state

-- Function to check and update the grey flag
-- Flags for column restrictions
local should_grey_left_column_high_values = false  -- Grey out 9-F in left column for volume/panning
local should_grey_right_column_high_values = false  -- Grey out 1-F in right column when left=8

local function updateEffectCanvasGreyFlag()
  should_grey_left_column_high_values = false
  should_grey_right_column_high_values = false
  
  if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
    local song = renoise.song()
    local sub_column_type = song.selected_sub_column_type
    
    -- In volume/panning subcolumns: grey out left column 9-F 
    if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME or 
       sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
      should_grey_left_column_high_values = true
      
      -- If left column is AT 8, also grey out right column values 1-F
      if selected_x == 8 then
        should_grey_right_column_high_values = true
      end
    end
  end
end

-- Canvas update timer for automatic subcolumn detection
local effect_canvas_update_timer = nil
local last_sub_column_type = nil

-- Canvas-based Note Grid Dialog for Renoise v6.2+
local note_canvas_dialog = nil
local note_canvas = nil
local note_canvas_width = 420  -- 12 notes × 35px = 420px wide (more space!)
local note_canvas_height = 165  -- 10 octaves × 15px + 1 row for 000/OFF = 165px (no extra space)
local note_cell_width = 35
local note_cell_height = 15
local note_columns = 12  -- C, C#, D, D#, E, F, F#, G, G#, A, A#, B  
local note_rows = 11     -- Octaves 0-9 + 1 row for 000/OFF
local note_hover_column = -1  -- 0-11 (C to B)
local note_hover_row = -1     -- 0-9 (octaves)
local note_selected_note = ""
local note_status_text = nil
local note_editstep_enabled = false

-- Canvas-based Main Dialog for Renoise v6.2+ (combines note and effect canvases)
local main_canvas_dialog = nil
local main_note_canvas = nil
local main_effect_canvas = nil
local main_note_status_text = nil
local main_effect_status_text = nil



-- Effect names for known effects (from PakettiPatternEditorCheatSheet.lua)
local effect_names = {
  ["0A"] = "Set arpeggio",
  ["0U"] = "Slide Pitch up",
  ["0D"] = "Slide Pitch down", 
  ["0G"] = "Glide towards given note",
  ["0I"] = "Fade Volume in",
  ["0O"] = "Fade Volume out",
  ["0C"] = "Cut volume to x after y ticks",
  ["0Q"] = "Delay note",
  ["0M"] = "Set note volume",
  ["0S"] = "Trigger sample slice number",
  ["0B"] = "Play Sample Backwards/forwards",
  ["0R"] = "Retrigger line",
  ["0Y"] = "Maybe trigger line with probability",
  ["0Z"] = "Trigger Phrase",
  ["0V"] = "Set Vibrato",
  ["0T"] = "Set Tremolo",
  ["0N"] = "Set Auto Pan",
  ["0E"] = "Set Active Sample Envelope's Position",
  ["0L"] = "Set Track Volume Level",
  ["0P"] = "Set Track Pan",
  ["0W"] = "Set Track Surround Width",
  ["0J"] = "Set Track Routing",
  ["0X"] = "Stop all notes and FX",
  ["ZT"] = "Set tempo",
  ["ZL"] = "Set Lines Per Beat (LPB)",
  ["ZK"] = "Set Ticks Per Line (TPL)",
  ["ZG"] = "Enable/disable Groove",
  ["ZB"] = "Break pattern and jump to line",
  ["ZD"] = "Delay (pause) pattern"
}

-- Function to format effect status with name info (DIALOG TEXT ONLY - not status bar)
local function format_effect_status(combined_hex, decimal_value)
  return combined_hex .. "\n" .. decimal_value
end

-- Pattern column status display is handled by show_current_status() from PakettiPatternEditorCheatSheet.lua


-- Canvas text drawing functions for the effect hover dialog
local function draw_digit_0(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_digit_1(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/2, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

local function draw_digit_2(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_digit_3(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:move_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_digit_4(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:move_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_digit_5(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:stroke()
end

local function draw_digit_6(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:stroke()
end

local function draw_digit_7(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size/2, y + size)
  ctx:stroke()
end

local function draw_digit_8(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

local function draw_digit_9(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y + size)
  ctx:line_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + size, y + size/2)
  ctx:stroke()
end

local function draw_letter_A(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x + size/2, y)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_B(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:line_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_letter_C(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:stroke()
end

local function draw_letter_D(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + 3*size/4, y + size)
  ctx:line_to(x + size, y + 3*size/4)
  ctx:line_to(x + size, y + size/4)
  ctx:line_to(x + 3*size/4, y)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_letter_E(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_F(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y + size)
  ctx:line_to(x, y)
  ctx:line_to(x + size, y)
  ctx:move_to(x, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_letter_G(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size, y)
  ctx:line_to(x, y)
  ctx:line_to(x, y + size)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x + size, y + size/2)
  ctx:line_to(x + size/2, y + size/2)
  ctx:stroke()
end

local function draw_letter_O(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x, y)
  ctx:line_to(x + size, y)
  ctx:line_to(x + size, y + size)
  ctx:line_to(x, y + size)
  ctx:line_to(x, y)
  ctx:stroke()
end

local function draw_space(ctx, x, y, size)
  -- Space character - do nothing
end

local function draw_dash(ctx, x, y, size)
  ctx:begin_path()
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

local function draw_hash(ctx, x, y, size)
  ctx:begin_path()
  -- Two vertical lines
  ctx:move_to(x + size/3, y + size/4)
  ctx:line_to(x + size/3, y + 3*size/4)
  ctx:move_to(x + 2*size/3, y + size/4)
  ctx:line_to(x + 2*size/3, y + 3*size/4)
  -- Two horizontal lines
  ctx:move_to(x + size/6, y + size/3)
  ctx:line_to(x + 5*size/6, y + size/3)
  ctx:move_to(x + size/6, y + 2*size/3)
  ctx:line_to(x + 5*size/6, y + 2*size/3)
  ctx:stroke()
end

local function draw_plus(ctx, x, y, size)
  ctx:begin_path()
  -- Vertical line
  ctx:move_to(x + size/2, y + size/4)
  ctx:line_to(x + size/2, y + 3*size/4)
  -- Horizontal line
  ctx:move_to(x + size/4, y + size/2)
  ctx:line_to(x + 3*size/4, y + size/2)
  ctx:stroke()
end

-- Letter lookup table for canvas text rendering
local letter_functions = {
  ["0"] = draw_digit_0, ["1"] = draw_digit_1, ["2"] = draw_digit_2, ["3"] = draw_digit_3,
  ["4"] = draw_digit_4, ["5"] = draw_digit_5, ["6"] = draw_digit_6, ["7"] = draw_digit_7,
  ["8"] = draw_digit_8, ["9"] = draw_digit_9,
  A = draw_letter_A, B = draw_letter_B, C = draw_letter_C, D = draw_letter_D,
  E = draw_letter_E, F = draw_letter_F, G = draw_letter_G, O = draw_letter_O,
  [" "] = draw_space, ["-"] = draw_dash, ["#"] = draw_hash, ["+"] = draw_plus
}

-- Function to draw text on canvas
local function draw_canvas_text(ctx, text, x, y, size)
  local current_x = x
  local letter_spacing = size * 1.2
  
  for i = 1, #text do
    local char = text:sub(i, i):upper()
    local letter_func = letter_functions[char]
    if letter_func then
      letter_func(ctx, current_x, y, size)
    end
    current_x = current_x + letter_spacing
  end
end

function pakettiPlayerProCanvasDrawEffect(ctx)
  local w, h = canvas_width, canvas_height
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Update the grey flag
  updateEffectCanvasGreyFlag()
  local max_right_column_value = should_grey_right_column_high_values and 0 or 15
  
  -- Color scheme based on mode
  local bg_color, text_color, hover_color, selected_color, border_color, cell_bg_color, grey_bg_color, grey_text_color
  
  if preferences.pakettiPlayerProEffectDialogDarkMode.value then
    -- Dark mode: black background, white text, white hover/selected
    bg_color = {20, 20, 30, 255}
    text_color = {255, 255, 255, 255}
    hover_color = {255, 255, 255, 255}  -- White hover
    selected_color = {255, 255, 255, 255}  -- White selected
    border_color = {100, 100, 100, 255}
    cell_bg_color = {40, 40, 50, 255}
    grey_bg_color = {30, 30, 35, 255}  -- Darker grey for disabled
    grey_text_color = {80, 80, 80, 255}  -- Dark grey text
  else
    -- Light mode: white background, black text, black hover/selected
    bg_color = {240, 240, 250, 255}
    text_color = {20, 20, 20, 255}
    hover_color = {0, 0, 0, 255}  -- Black hover
    selected_color = {0, 0, 0, 255}  -- Black selected
    border_color = {150, 150, 150, 255}
    cell_bg_color = {220, 220, 230, 255}
    grey_bg_color = {200, 200, 200, 255}  -- Light grey for disabled
    grey_text_color = {150, 150, 150, 255}  -- Light grey text
  end
  
  -- Draw background
  ctx.fill_color = bg_color
  ctx:fill_rect(0, 0, w, h)
  
  -- Draw hex values (0-F) in two columns - tight layout starting from top
  local hex_chars = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
  
  for i = 0, 15 do
    local y = column_start_y + i * cell_height
    
    -- Left column (X values)
    local is_left_hovered = (hover_column == "left" and hover_index == i)
    local is_left_selected = (selected_x == i)
    
    -- Check if this value should be greyed out (9-F when in volume/panning)
    local is_disabled = should_grey_left_column_high_values and i >= 9
    
    -- Show persistent selection AND hover (both in write and preview mode)
    local show_as_selected = false
    if not is_disabled then
      show_as_selected = is_left_selected or is_left_hovered
    end
    
    if is_disabled then
      ctx.fill_color = grey_bg_color
    elseif show_as_selected then
      ctx.fill_color = selected_color
    else
      ctx.fill_color = cell_bg_color
    end
    ctx:fill_rect(left_column_x, y, cell_width, cell_height)
    
    ctx.stroke_color = border_color
    ctx.line_width = 1
    ctx:stroke_rect(left_column_x, y, cell_width, cell_height)
    
    if is_disabled then
      ctx.stroke_color = grey_text_color
    else
      ctx.stroke_color = show_as_selected and bg_color or text_color
    end
    ctx.line_width = 1
    -- Center text horizontally and vertically
    local text_size = 8
    local char_width = 9  -- Adjusted width for better centering
    local centered_x = left_column_x + (cell_width - char_width) / 2
    local center_y = y + (cell_height - text_size) / 2
    draw_canvas_text(ctx, hex_chars[i + 1], centered_x, center_y, text_size)
    
    -- Right column (Y values)
    local is_right_hovered = (hover_column == "right" and hover_index == i)
    local is_right_selected = (selected_y == i)
    
    -- Show persistent selection AND hover (both in write and preview mode)
    local show_as_selected_right = false
    show_as_selected_right = is_right_selected or is_right_hovered
    
    -- Check if this right column value should be greyed out (1-F values when left=8 and in volume/panning)
    local should_grey_right_value = should_grey_right_column_high_values and i >= 1 and i <= 15
    
    if should_grey_right_value then
      -- Grey out this cell using proper grey background
      ctx.fill_color = grey_bg_color
    elseif show_as_selected_right then
      ctx.fill_color = selected_color
    else
      ctx.fill_color = cell_bg_color
    end
    ctx:fill_rect(right_column_x, y, cell_width, cell_height)
    
    ctx.stroke_color = border_color
    ctx.line_width = 1
    ctx:stroke_rect(right_column_x, y, cell_width, cell_height)
    
    -- Set text color based on state
    if should_grey_right_value then
      ctx.stroke_color = grey_text_color
    elseif show_as_selected_right then
      ctx.stroke_color = bg_color
    else
      ctx.stroke_color = text_color
    end
    ctx.line_width = 1
    -- Center text horizontally and vertically
    local text_size = 8
    local char_width = 9  -- Adjusted width for better centering
    local centered_x = right_column_x + (cell_width - char_width) / 2
    local center_y = y + (cell_height - text_size) / 2
    draw_canvas_text(ctx, hex_chars[i + 1], centered_x, center_y, text_size)
  end
end

function pakettiPlayerProCanvasHandleMouse(ev, status_text_widget, canvas_widget)
  -- Handle mouse exit - show current column status
  if ev.type == "exit" then
    show_current_status()
    return
  end
  
  local x = ev.position.x
  local y = ev.position.y
  
  -- Reset hover state
  hover_column = nil
  hover_index = -1
  
  -- Check if mouse is over left column (X values)
  if x >= left_column_x and x < left_column_x + cell_width and
     y >= column_start_y and y < column_start_y + 16 * cell_height then
    
    local index = math.floor((y - column_start_y) / cell_height)
    if index >= 0 and index <= 15 then
      -- Update flag to check current restrictions
      updateEffectCanvasGreyFlag()
      
      local is_disabled = should_grey_left_column_high_values and index >= 9
      
      if not is_disabled then
        hover_column = "left"
        hover_index = index
        
        -- Write on hover ONLY if Write mode is enabled
        if preferences.pakettiPlayerProEffectCanvasWrite.value and ev.type == "move" then
          selected_x = index  -- Update selection first
          updateEffectCanvasGreyFlag()  -- Update flag when left column changes
          
          -- Handle col2 restriction and memory logic for hover
          if should_grey_right_column_high_values then
            -- Moving into restricted state (col1=8): save current col2 if > 0, then force to 0
            if selected_y > 0 then
              previous_selected_y = selected_y  -- Save current selection
              selected_y = 0
              effect_canvas:update()  -- Update canvas to show new selection
            end
          else
            -- Moving out of restricted state (col1=0-7): restore previous col2 if we had one
            if previous_selected_y > 0 then
              selected_y = previous_selected_y
              previous_selected_y = 0  -- Clear memory after restoring
              effect_canvas:update()  -- Update canvas to show restored selection
            end
          end
          
          local combined_hex = string.format("%X%X", selected_x, selected_y)
          pakettiPlayerProCanvasWriteEffectToPattern("00", combined_hex)
          -- Update status text
          if status_text_widget then
            local decimal_value = tonumber(combined_hex, 16)
            status_text_widget.text = format_effect_status(combined_hex, decimal_value)
            -- Show subcolumn-aware status
            local song = renoise.song()
            local sub_column_type = song.selected_sub_column_type
            local decimal_value = tonumber(combined_hex, 16)
            
            if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
              renoise.app():show_status(string.format("Volume: %s (%d)", combined_hex, decimal_value))
            elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
              renoise.app():show_status(string.format("Panning: %s (%d)", combined_hex, decimal_value))
            elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
              renoise.app():show_status(string.format("Delay: %s (%d)", combined_hex, decimal_value))
            elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
              renoise.app():show_status(string.format("SampleFX: %s (%d)", combined_hex, decimal_value))
            else
              -- Effect column or other
              local effect_name = effect_names[combined_hex]
              if effect_name then
                renoise.app():show_status(string.format("%s - %s", combined_hex, effect_name))
              else
                renoise.app():show_status(combined_hex)
              end
            end
          end
        else
          -- Update status text for preview without writing (don't change selections)
          if ev.type == "move" and not preferences.pakettiPlayerProEffectCanvasWrite.value then
            local temp_combined_hex = string.format("%X%X", index, selected_y)
            if status_text_widget then
              local decimal_value = tonumber(temp_combined_hex, 16)
              status_text_widget.text = format_effect_status(temp_combined_hex, decimal_value)
              -- Show subcolumn-aware status for preview
              local song = renoise.song()
              local sub_column_type = song.selected_sub_column_type
              local decimal_value = tonumber(temp_combined_hex, 16)
              
              if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
                renoise.app():show_status(string.format("Volume: %s (%d)", temp_combined_hex, decimal_value))
              elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
                renoise.app():show_status(string.format("Panning: %s (%d)", temp_combined_hex, decimal_value))
              elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
                renoise.app():show_status(string.format("Delay: %s (%d)", temp_combined_hex, decimal_value))
              elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
                renoise.app():show_status(string.format("SampleFX: %s (%d)", temp_combined_hex, decimal_value))
              else
                -- Effect column or other
                local effect_name = effect_names[temp_combined_hex]
                if effect_name then
                  renoise.app():show_status(string.format("%s - %s", temp_combined_hex, effect_name))
                else
                  renoise.app():show_status(temp_combined_hex)
                end
              end
            end
          end
      end
      
      -- Handle click on left column (always writes regardless of Write mode)
      if ev.type == "down" then
        selected_x = index
        updateEffectCanvasGreyFlag()  -- Update flag when left column changes
        
        -- Handle col2 restriction and memory logic
        if should_grey_right_column_high_values then
          -- Moving into restricted state (col1=8): save current col2 if > 0, then force to 0
          if selected_y > 0 then
            previous_selected_y = selected_y  -- Save current selection
            selected_y = 0
            effect_canvas:update()  -- Update canvas to show new selection
          end
        else
          -- Moving out of restricted state (col1=0-7): restore previous col2 if we had one
          if previous_selected_y > 0 then
            selected_y = previous_selected_y
            previous_selected_y = 0  -- Clear memory after restoring
            effect_canvas:update()  -- Update canvas to show restored selection
          end
        end
        
        local combined_hex = string.format("%X%X", selected_x, selected_y)
        pakettiPlayerProCanvasWriteEffectToPattern("00", combined_hex)
        -- Debug print with subcolumn context
        local song = renoise.song()
        local sub_column_type = song.selected_sub_column_type
        local decimal_value = tonumber(combined_hex, 16)
        
        if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
          print("Volume: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
          print("Panning: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
          print("Delay: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
          print("SampleFX: " .. combined_hex .. " (" .. decimal_value .. ")")
        else
          print("Selected X=" .. string.format("%X", selected_x) .. ", Effect=" .. combined_hex)
        end
        
        -- Redraw canvas to update greying based on new left column selection
        if canvas_widget then
          canvas_widget:update()
        end
        -- Determine column type for status message
        local song = renoise.song()
        local column_info = ""
        if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
          local sub_column_type = song.selected_sub_column_type
          if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
            column_info = " (Volume Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
            column_info = " (Panning Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
            column_info = " (Delay Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
            column_info = " (Sample FX Amount)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
            column_info = " (Sample FX Number)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
            column_info = " (Effect Number)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
            column_info = " (Effect Amount)"
          end
        else
          column_info = " (Effect Column)"
        end
        -- Show subcolumn-aware status for click
        local song = renoise.song()
        local sub_column_type = song.selected_sub_column_type
        local decimal_value = tonumber(combined_hex, 16)
        
        if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
          renoise.app():show_status(string.format("Volume: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
          renoise.app():show_status(string.format("Panning: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
          renoise.app():show_status(string.format("Delay: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
          renoise.app():show_status(string.format("SampleFX: %s (%d)", combined_hex, decimal_value))
        else
          -- Show subcolumn-aware status (fallback for non-subcolumn contexts)
          renoise.app():show_status("Selected X=" .. string.format("%X", selected_x) .. ", Value=" .. combined_hex .. column_info)
        end
        -- Update status text (show hex and decimal like legacy)
        if status_text_widget then
          local decimal_value = tonumber(combined_hex, 16)
          status_text_widget.text = format_effect_status(combined_hex, decimal_value)
        end
      end
      end
    end
  end
  
  -- Check if mouse is over right column (Y values)
  if x >= right_column_x and x < right_column_x + cell_width and
     y >= column_start_y and y < column_start_y + 16 * cell_height then
    
    local index = math.floor((y - column_start_y) / cell_height)
    
    -- Check flag for restrictions
    updateEffectCanvasGreyFlag()
    local max_allowed_index = should_grey_right_column_high_values and 0 or 15
    
    if index >= 0 and index <= max_allowed_index then
      hover_column = "right"
      hover_index = index
      
      -- Write on hover ONLY if Write mode is enabled
      if preferences.pakettiPlayerProEffectCanvasWrite.value and ev.type == "move" then
        -- Check if this is a restricted hover (trying to hover 1-F when col1=8)
        if should_grey_right_column_high_values and index > 0 then
          -- Prevent hovering on restricted values, but allow hovering on 0
          return
        end
        local combined_hex = string.format("%X%X", selected_x, index)
        pakettiPlayerProCanvasWriteEffectToPattern("00", combined_hex)
        selected_y = index  -- Only update selection AFTER writing
        -- Update status text
        if effect_status_text then
          local decimal_value = tonumber(combined_hex, 16)
          effect_status_text.text = format_effect_status(combined_hex, decimal_value)
        end
        
        -- Show subcolumn-aware status for right column write hover
        local song = renoise.song()
        local sub_column_type = song.selected_sub_column_type
        local decimal_value = tonumber(combined_hex, 16)
        
        if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
          renoise.app():show_status(string.format("Volume: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
          renoise.app():show_status(string.format("Panning: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
          renoise.app():show_status(string.format("Delay: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
          renoise.app():show_status(string.format("SampleFX: %s (%d)", combined_hex, decimal_value))
        else
          local column_info = ""
          if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
            if sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
              column_info = " (Effect Number)"
            elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
              column_info = " (Effect Amount)"
            end
          else
            column_info = " (Effect Column)"
          end
          renoise.app():show_status("Write Y=" .. string.format("%X", index) .. ", Value=" .. combined_hex .. column_info)
        end
      else
        -- Update status text for preview without writing (don't change selections)
        if ev.type == "move" and not preferences.pakettiPlayerProEffectCanvasWrite.value then
          -- Check if this is a restricted hover (trying to hover 1-F when col1=8)
          if should_grey_right_column_high_values and index > 0 then
            -- Prevent preview on restricted values, but allow preview on 0
            return
          end
          local temp_combined_hex = string.format("%X%X", selected_x, index)
          if effect_status_text then
            local decimal_value = tonumber(temp_combined_hex, 16)
            effect_status_text.text = format_effect_status(temp_combined_hex, decimal_value)
          end
          
          -- Show subcolumn-aware status for right column hover
          local song = renoise.song()
          local sub_column_type = song.selected_sub_column_type
          local decimal_value = tonumber(temp_combined_hex, 16)
          
          if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
            renoise.app():show_status(string.format("Volume: %s (%d)", temp_combined_hex, decimal_value))
          elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
            renoise.app():show_status(string.format("Panning: %s (%d)", temp_combined_hex, decimal_value))
          elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
            renoise.app():show_status(string.format("Delay: %s (%d)", temp_combined_hex, decimal_value))
          elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
            renoise.app():show_status(string.format("SampleFX: %s (%d)", temp_combined_hex, decimal_value))
          else
            local column_info = ""
            if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
              if sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
                column_info = " (Effect Number)"
              elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
                column_info = " (Effect Amount)"
              end
            else
              column_info = " (Effect Column)"
            end
            renoise.app():show_status("Hover Y=" .. string.format("%X", index) .. ", Value=" .. temp_combined_hex .. column_info)
          end
        end
      end
      
      -- Handle click on right column (always writes regardless of Write mode)
      if ev.type == "down" then
        -- Check if this is a restricted click (trying to click 1-F when col1=8)
        if should_grey_right_column_high_values and index > 0 then
          -- Prevent selecting restricted values, but allow clicking 0
          return
        end
        selected_y = index
        local combined_hex = string.format("%X%X", selected_x, selected_y)
        pakettiPlayerProCanvasWriteEffectToPattern("00", combined_hex)
        -- Debug print for right column with subcolumn context
        local song = renoise.song()
        local sub_column_type = song.selected_sub_column_type
        local decimal_value = tonumber(combined_hex, 16)
        
        if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
          print("Volume: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
          print("Panning: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
          print("Delay: " .. combined_hex .. " (" .. decimal_value .. ")")
        elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
          print("SampleFX: " .. combined_hex .. " (" .. decimal_value .. ")")
        else
          print("Selected Y=" .. string.format("%X", selected_y) .. ", Effect Amount=" .. combined_hex)
        end
        -- Determine column type for status message
        local song = renoise.song()
        local column_info = ""
        if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
          local sub_column_type = song.selected_sub_column_type
          if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
            column_info = " (Volume Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
            column_info = " (Panning Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
            column_info = " (Delay Column)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
            column_info = " (Sample FX Amount)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
            column_info = " (Sample FX Number)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
            column_info = " (Effect Number)"
          elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
            column_info = " (Effect Amount)"
          end
        else
          column_info = " (Effect Column)"
        end
        -- Show subcolumn-aware status for right column click
        local song = renoise.song()
        local sub_column_type = song.selected_sub_column_type
        local decimal_value = tonumber(combined_hex, 16)
        
        if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
          renoise.app():show_status(string.format("Volume: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
          renoise.app():show_status(string.format("Panning: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
          renoise.app():show_status(string.format("Delay: %s (%d)", combined_hex, decimal_value))
        elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
          renoise.app():show_status(string.format("SampleFX: %s (%d)", combined_hex, decimal_value))
        else
          renoise.app():show_status("Selected Y=" .. string.format("%X", selected_y) .. ", Value=" .. combined_hex .. column_info)
        end
        -- Update status text (show hex and decimal like legacy)
        if status_text_widget then
          local decimal_value = tonumber(combined_hex, 16)
          status_text_widget.text = format_effect_status(combined_hex, decimal_value)
        end
      end
    end
  end
  
  -- Update canvas to reflect hover changes
  if effect_canvas then
    effect_canvas:update()
  end
end

function pakettiPlayerProCanvasWriteEffectToPattern(effect_code, arg_value)
  local song = renoise.song()
  
  -- Function to make specific columns visible across selection
  local function make_column_visible(column_type)
    if song.selection_in_pattern then
      for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
        local track = song:track(t)
        if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          if column_type == "volume" then
            track.volume_column_visible = true
          elseif column_type == "panning" then
            track.panning_column_visible = true
          elseif column_type == "delay" then
            track.delay_column_visible = true
          elseif column_type == "samplefx" then
            track.sample_effects_column_visible = true
          elseif column_type == "effect" then
            track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
          end
        end
      end
    else
      local track = song.selected_track
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        if column_type == "volume" then
          track.volume_column_visible = true
        elseif column_type == "panning" then
          track.panning_column_visible = true
        elseif column_type == "delay" then
          track.delay_column_visible = true
        elseif column_type == "samplefx" then
          track.sample_effects_column_visible = true
        elseif column_type == "effect" then
          track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
        end
      end
    end
  end
  
  -- Check if X checkbox is enabled for subcolumn detection
  if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
    local sub_column_type = song.selected_sub_column_type
    local decimal_value = tonumber(arg_value, 16) or 0
    
    -- Handle different subcolumn types with selection support
    if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
      -- In volume subcolumn - write to volume_value
      make_column_visible("volume")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or note_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = song:pattern(song.selected_pattern_index):track(t):line(i).note_columns[col]
                  if note_column then
                    note_column.volume_value = math.min(decimal_value, 128)
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_note_column then
          song.selected_note_column.volume_value = math.min(decimal_value, 128)
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
      -- In panning subcolumn - write to panning_value
      make_column_visible("panning")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or note_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = song:pattern(song.selected_pattern_index):track(t):line(i).note_columns[col]
                  if note_column then
                    note_column.panning_value = math.min(decimal_value, 128)
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_note_column then
          song.selected_note_column.panning_value = math.min(decimal_value, 128)
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
      -- In delay subcolumn - write to delay_value
      make_column_visible("delay")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or note_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = song:pattern(song.selected_pattern_index):track(t):line(i).note_columns[col]
                  if note_column then
                    note_column.delay_value = math.min(decimal_value, 255)
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_note_column then
          song.selected_note_column.delay_value = math.min(decimal_value, 255)
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      -- In sample effect amount subcolumn
      make_column_visible("samplefx")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or note_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = song:pattern(song.selected_pattern_index):track(t):line(i).note_columns[col]
                  if note_column then
                    note_column.effect_amount_value = decimal_value
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_note_column then
          song.selected_note_column.effect_amount_value = decimal_value
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
      -- In effect number subcolumn - write to number
      make_column_visible("effect")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local effect_columns_visible = track.visible_effect_columns
            local total_columns_visible = note_columns_visible + effect_columns_visible
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or note_columns_visible + 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or total_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                local column_index = col - note_columns_visible
                if column_index > 0 and column_index <= effect_columns_visible then
                  local effect_column = song:pattern(song.selected_pattern_index):track(t):line(i):effect_column(column_index)
                  if effect_column then
                    effect_column.number_string = arg_value
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_effect_column then
          song.selected_effect_column.number_string = arg_value
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
      -- In effect amount subcolumn - write to amount_value
      make_column_visible("effect")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local effect_columns_visible = track.visible_effect_columns
            local total_columns_visible = note_columns_visible + effect_columns_visible
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or note_columns_visible + 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or total_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                local column_index = col - note_columns_visible
                if column_index > 0 and column_index <= effect_columns_visible then
                  local effect_column = song:pattern(song.selected_pattern_index):track(t):line(i):effect_column(column_index)
                  if effect_column then
                    effect_column.amount_value = decimal_value
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_effect_column then
          song.selected_effect_column.amount_value = decimal_value
        end
      end
      return
      
    elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
      -- In sample effect number subcolumn
      make_column_visible("samplefx")
      
      if song.selection_in_pattern then
        for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
          local track = song:track(t)
          if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
            local note_columns_visible = track.visible_note_columns
            local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or 1
            local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or note_columns_visible
            for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
              for col = start_column, end_column do
                if col <= note_columns_visible then
                  local note_column = song:pattern(song.selected_pattern_index):track(t):line(i).note_columns[col]
                  if note_column then
                    note_column.effect_number_string = arg_value
                  end
                end
              end
            end
          end
        end
      else
        if song.selected_note_column then
          song.selected_note_column.effect_number_string = arg_value
        end
      end
      return
    end
  end
  
  -- Default behavior: write to effect columns as amount_value
  local decimal_value = tonumber(arg_value, 16) or 0
  
  -- Ensure effect columns are visible
  if song.selection_in_pattern then
    -- Write to selection
    for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
      local track = song:track(t)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
        local note_columns_visible = track.visible_note_columns
        local effect_columns_visible = track.visible_effect_columns
        local total_columns_visible = note_columns_visible + effect_columns_visible
        
        local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or note_columns_visible + 1
        local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or total_columns_visible
        
        for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
          for col = start_column, end_column do
            local column_index = col - note_columns_visible
            if column_index > 0 and column_index <= effect_columns_visible then
              local effect_column = song:pattern(song.selected_pattern_index):track(t):line(i):effect_column(column_index)
              if effect_column then
                effect_column.amount_value = decimal_value
              end
            end
          end
        end
      end
    end
  else
    -- Write to current line
    local track = song.selected_track
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      track.visible_effect_columns = math.max(track.visible_effect_columns, 1)
      
      if song.selected_effect_column_index > 0 then
        -- Write to selected effect column
        local effect_column = song.selected_effect_column
        if effect_column then
          effect_column.amount_value = decimal_value
        end
      else
        -- Write to first effect column
        local line = song.selected_line
        local effect_column = line:effect_column(1)
        if effect_column then
          effect_column.amount_value = decimal_value
        end
      end
    end
  end
  
  -- Keep pattern editor focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function pakettiPlayerProEffectDialogCanvas()
  if effect_canvas_dialog and effect_canvas_dialog.visible then
    pakettiPlayerProEffectCanvasRemoveUpdateTimer()
    effect_canvas_dialog:close()
    effect_canvas_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Create canvas first
  effect_canvas = vb:canvas {
    width = canvas_width,
    height = canvas_height,
    mode = "plain",
    render = pakettiPlayerProCanvasDrawEffect,
    mouse_handler = function(ev) 
      pakettiPlayerProCanvasHandleMouse(ev, effect_status_text, effect_canvas) 
    end,
    mouse_events = {"down", "up", "move", "exit"}
  }
  
  -- Create status text
  effect_status_text = vb:text {
    text = "00\n0",
    font = "mono",
    align = "center",
    width = 44,
    tooltip = "Current hex value and decimal equivalent"
  }
  
  local dialog_content = vb:column {
    margin = 5,
    
    -- Canvas for effect grid
    effect_canvas,
    
    -- Status display outside canvas
    effect_status_text,
    
    vb:column {
      vb:button {
        text = "CLR",
        width = 44,
        tooltip = "Clear selection",
        notifier = function()
          local song = renoise.song()
          
          if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
            -- X mode: Clear the current subcolumn type across selection
            local sub_column_type = song.selected_sub_column_type
            local column_name = ""
            
            if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
              column_name = "Volume"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear volume
            elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
              column_name = "Panning" 
              pakettiPlayerProCanvasWriteEffectToPattern("00", "40")  -- Center panning
            elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
              column_name = "Delay"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear delay
            elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
              column_name = "Sample FX Amount"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear sample fx amount
            elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
              column_name = "Sample FX Number"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear sample fx number
            elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
              column_name = "Effect Number"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear effect number
            elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
              column_name = "Effect Amount"
              pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear effect amount
            else
              column_name = "Unknown Column"
            end
            
            renoise.app():show_status("Cleared " .. column_name .. " column selection")
          else
            -- Normal mode: Clear effect columns and reset canvas selection
            if song.selection_in_pattern then
              -- Clear selection
              for t = song.selection_in_pattern.start_track, song.selection_in_pattern.end_track do
                local track = song:track(t)
                local note_columns_visible = track.visible_note_columns
                local effect_columns_visible = track.visible_effect_columns
                local total_columns_visible = note_columns_visible + effect_columns_visible
                
                local start_column = (t == song.selection_in_pattern.start_track) and song.selection_in_pattern.start_column or note_columns_visible + 1
                local end_column = (t == song.selection_in_pattern.end_track) and song.selection_in_pattern.end_column or total_columns_visible
                
                for i = song.selection_in_pattern.start_line, song.selection_in_pattern.end_line do
                  for col = start_column, end_column do
                    local column_index = col - note_columns_visible
                    if column_index > 0 and column_index <= effect_columns_visible then
                      local effect_column = song:pattern(song.selected_pattern_index):track(t):line(i):effect_column(column_index)
                      if effect_column then
                        effect_column:clear()
                      end
                    end
                  end
                end
              end
              renoise.app():show_status("Cleared effect columns in selection")
            else
              -- Clear current effect column
              if song.selected_effect_column then
                song.selected_effect_column:clear()
                renoise.app():show_status("Cleared current effect column")
              end
            end
            
            -- Reset canvas selection
            selected_x = 0
            selected_y = 0
          end
          
          if effect_canvas then
            effect_canvas:update()
          end
          if effect_status_text then
            effect_status_text.text = format_effect_status("00", 0)
          end
        end
      },
      vb:button {
        text = preferences.pakettiPlayerProEffectDialogDarkMode.value and "Light" or "Dark",
        width = 44,
        tooltip = "PlayerPro Dark or Light Mode",
        notifier = function()
          preferences.pakettiPlayerProEffectDialogDarkMode.value = not preferences.pakettiPlayerProEffectDialogDarkMode.value
          
          if effect_canvas then
            effect_canvas:update()
          end
          -- Close and reopen dialog to update button text
          if effect_canvas_dialog then
            pakettiPlayerProEffectCanvasRemoveUpdateTimer()
            effect_canvas_dialog:close()
            effect_canvas_dialog = nil
          end
          pakettiPlayerProEffectDialogCanvas()
        end
      },
      vb:row {
        vb:checkbox {
          value = preferences.pakettiPlayerProEffectCanvasWrite.value,
          tooltip = "Write on hover when enabled, otherwise click to write",
          notifier = function(value)
            preferences.pakettiPlayerProEffectCanvasWrite.value = value
            preferences:save_as("preferences.xml")
          end
        },
        vb:text {
          text = "W"
        }
      },
      vb:row {
        vb:checkbox {
          value = preferences.pakettiPlayerProEffectCanvasSubColumn.value,
          tooltip = "Auto-detect subcolumn (effect number/amount) when enabled",
          notifier = function(value)
            preferences.pakettiPlayerProEffectCanvasSubColumn.value = value
          end
        },
        vb:text {
          text = "X"
        }
      }
    }
  }
  
  local keyhandler = my_keyhandler_func
  effect_canvas_dialog = renoise.app():show_custom_dialog("", dialog_content, keyhandler)
  
  -- Show current column status and set focus to pattern editor
  show_current_status()
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Setup canvas update timer for automatic subcolumn detection
  pakettiPlayerProEffectCanvasSetupUpdateTimer()
end

-- Setup canvas update timer for automatic subcolumn detection
function pakettiPlayerProEffectCanvasSetupUpdateTimer()
  if effect_canvas_update_timer then
    renoise.tool():remove_timer(effect_canvas_update_timer)
  end
  
  effect_canvas_update_timer = function()
    -- Check if dialog is still open
    if not effect_canvas_dialog or not effect_canvas_dialog.visible or not effect_canvas then
      pakettiPlayerProEffectCanvasRemoveUpdateTimer()
      return
    end
    
    -- Check if subcolumn has changed
    local song = renoise.song()
    local current_sub_column_type = song.selected_sub_column_type
    
    if current_sub_column_type ~= last_sub_column_type then
      last_sub_column_type = current_sub_column_type
      -- Update canvas when subcolumn changes
      effect_canvas:update()
    end
  end
  
  -- Update every 100ms for responsive subcolumn detection
  renoise.tool():add_timer(effect_canvas_update_timer, 100)
end

-- Remove canvas update timer
function pakettiPlayerProEffectCanvasRemoveUpdateTimer()
  if effect_canvas_update_timer then
    pcall(function()
      renoise.tool():remove_timer(effect_canvas_update_timer)
    end)
    effect_canvas_update_timer = nil
  end
end

-- Canvas-based Note Grid Dialog for Renoise v6.2+
function pakettiPlayerProNoteGridShowCanvasGrid()
  if note_canvas_dialog and note_canvas_dialog.visible then
    -- Clean up canvas instrument observer
    if canvas_instrument_observer then
      PakettiPlayerProRemoveInstrumentObserver(canvas_instrument_observer)
      canvas_instrument_observer = nil
    end
    note_canvas_dialog:close()
    note_canvas_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Create instrument items array
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end
  
  local selected_instrument_index = renoise.song().selected_instrument_index
  local selected_instrument_value = selected_instrument_index + 1
  
  -- Create canvas first
  note_canvas = vb:canvas {
    width = note_canvas_width,
    height = note_canvas_height,
    mode = "plain",
    render = pakettiPlayerProNoteCanvasDrawGrid,
    mouse_handler = function(ev)
      pakettiPlayerProNoteCanvasHandleMouse(ev, note_status_text, note_canvas, pakettiPlayerProNoteCanvasInsertNote)
    end,
    mouse_events = {"down", "up", "move", "exit"}
  }
  
  local dialog_content = vb:column {
    --margin = 5,
    
    -- Instrument selector row
    vb:row {
      vb:text {
        text = "Instrument",
        style = "strong",
        font = "bold"
      },
      vb:popup {
        items = instrument_items,
        width = 265,
        id = "canvas_instrument_popup",
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
          print("Canvas Dialog - Instrument changed to: " .. tostring(instrument))
        end
      },
      vb:button {
        text = "Refresh",
        width = 90,
        notifier = function()
          local updated_instrument_items = {"<None>"}
          for i = 0, #renoise.song().instruments - 1 do
            local instrument = renoise.song().instruments[i + 1]
            table.insert(updated_instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
          end
          if vb.views["canvas_instrument_popup"] then
            vb.views["canvas_instrument_popup"].items = updated_instrument_items
          end
        end
      }
    },
    
    -- Canvas for note grid
    note_canvas,
    
    -- Status display outside canvas
    note_status_text,
    
    vb:row {
      vb:checkbox {
        value = note_editstep_enabled,
        tooltip = "Fill Selection with EditStep",
        notifier = function(value)
          note_editstep_enabled = value
        end
      },
      vb:text {
        text = "EditStep"
      },
      vb:checkbox {
        value = preferences.pakettiPlayerProNoteCanvasWrite.value,
        tooltip = "Write on hover when enabled, otherwise click to write",
        notifier = function(value)
          preferences.pakettiPlayerProNoteCanvasWrite.value = value
        end
      },
      vb:text {
        text = "Write"
      },
      vb:checkbox {
        value = preferences.pakettiPlayerProNoteCanvasSpray.value,
        tooltip = "When EditStep + Write: spray notes following EditStep progression",
        notifier = function(value)
          preferences.pakettiPlayerProNoteCanvasSpray.value = value
        end
      },
      vb:text {
        text = "Spray"
      },
      vb:checkbox {
        value = preferences.pakettiPlayerProNoteCanvasClearSelection.value,
        tooltip = "Clear selection before writing notes with EditStep",
        notifier = function(value)
          preferences.pakettiPlayerProNoteCanvasClearSelection.value = value
        end
      },
      vb:text {
        text = "Clear Selection Before Write"
      }
    },
    vb:row {
      vb:checkbox {
        value = preferences.pakettiPlayerProSmartSubColumn and preferences.pakettiPlayerProSmartSubColumn.value or false,
        tooltip = "Open effect dialog when in volume/panning/delay/samplefx subcolumns",
        notifier = function(value)
          preferences.pakettiPlayerProSmartSubColumn.value = value
        end
      },
      vb:text {
        text = "Smart SubColumn"
      }
    },
    vb:row {
      vb:checkbox {
        value = preferences.pakettiPlayerProAlwaysOpen and preferences.pakettiPlayerProAlwaysOpen.value or false,
        tooltip = "Automatically open appropriate dialog when moving between note/effect columns",
        notifier = function(value)
          preferences.pakettiPlayerProAlwaysOpen.value = value
          -- Start or stop the always open system
          if value then
            pakettiPlayerProStartAlwaysOpen()
          else
            pakettiPlayerProStopAlwaysOpen()
          end
        end
      },
      vb:text {
        text = "Always Open Dialog"
      }
    },
    vb:row {
      vb:button {
        text = preferences.pakettiPlayerProEffectDialogDarkMode.value and "Light" or "Dark",
        width = 60,
        tooltip = "PlayerPro Dark or Light Mode",
        notifier = function()
          preferences.pakettiPlayerProEffectDialogDarkMode.value = not preferences.pakettiPlayerProEffectDialogDarkMode.value
          
          -- Update canvas immediately
          if note_canvas then
            note_canvas:update()
          end
          
          -- Close and reopen dialog to update button text
          if note_canvas_dialog then
            note_canvas_dialog:close()
            note_canvas_dialog = nil
          end
          pakettiPlayerProNoteGridShowCanvasGrid()
        end
      },
      vb:button {
        text = preferences.pakettiPlayerProNoteCanvasPianoKeys.value and "Piano Mode" or "Piano Mode",
        width = 80,
        tooltip = "Toggle piano key coloring (grey sharps)",
        notifier = function()
          preferences.pakettiPlayerProNoteCanvasPianoKeys.value = not preferences.pakettiPlayerProNoteCanvasPianoKeys.value
          
          -- Update canvas immediately
          if note_canvas then
            note_canvas:update()
          end
          
          -- No need to restart dialog for piano mode toggle
        end
      }
    }
  }
  
  local keyhandler = my_keyhandler_func
  note_canvas_dialog = renoise.app():show_custom_dialog("PlayerPro Note Grid Dialog", dialog_content, keyhandler)
  
  -- Add instrument observer after dialog is created
  canvas_instrument_observer = PakettiPlayerProCreateInstrumentObserver(vb, "canvas_instrument_popup", note_canvas_dialog)
  
  -- Set focus to pattern editor
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function pakettiPlayerProNoteCanvasDrawGrid(ctx)
  local w, h = note_canvas_width, note_canvas_height
  
  -- Clear canvas
  ctx:clear_rect(0, 0, w, h)
  
  -- Color scheme - clean uniform by default, optional piano styling
  local bg_color, white_key_color, black_key_color, hover_color, text_color, text_color_black, border_color
  local use_piano_keys = preferences.pakettiPlayerProNoteCanvasPianoKeys.value
  
  if preferences.pakettiPlayerProEffectDialogDarkMode.value then
    -- Dark mode - match effect canvas colors
    bg_color = {20, 20, 30, 255}         -- Dark background (same as effect canvas)
    white_key_color = {40, 40, 50, 255}  -- Dark cells (same as effect canvas)
    black_key_color = use_piano_keys and {30, 30, 35, 255} or {40, 40, 50, 255}  -- Slightly darker for black keys (if enabled)
    hover_color = {255, 255, 255, 255}   -- White hover (same as effect canvas)
    text_color = {255, 255, 255, 255}    -- White text (same as effect canvas)
    text_color_black = {200, 200, 200, 255}  -- Slightly dimmer for black keys
    border_color = {100, 100, 100, 255}  -- Gray border
  else
    -- Light mode
    bg_color = {240, 240, 240, 255}      -- Light background
    white_key_color = {255, 255, 255, 255}  -- White cells (uniform or white keys)
    black_key_color = use_piano_keys and {200, 200, 200, 255} or {255, 255, 255, 255}  -- Medium grey for black keys (if enabled)
    hover_color = {60, 60, 60, 255}      -- Dark hover (inverted)
    text_color = {0, 0, 0, 255}          -- Black text
    text_color_black = {40, 40, 40, 255}  -- Dark grey text for black keys (better contrast)
    border_color = {150, 150, 150, 255}  -- Gray border
  end
  
  -- Draw background
  ctx.fill_color = bg_color
  ctx:fill_rect(0, 0, w, h)
  
  -- Define which notes are black keys (sharps/flats) - only used if piano keys preference is enabled
  local black_keys = {false, true, false, true, false, false, true, false, true, false, true, false}  -- C, C#, D, D#, E, F, F#, G, G#, A, A#, B
  
  -- Draw grid (uniform by default, optional piano key styling)
  for row = 0, note_rows - 1 do  -- Octaves 0-9 + special row
    for col = 0, note_columns - 1 do  -- Notes C to B
      local x = col * note_cell_width
      local y = row * note_cell_height
      
      local is_hovered = (note_hover_column == col and note_hover_row == row)
      local note_text = ""
      
      -- Handle special bottom row for 000 and OFF
      if row == 10 then
        if col == 0 then
          note_text = "000"
        elseif col == 1 then  
          note_text = "OFF"
        else
          -- Skip empty cells in bottom row - don't draw anything
          note_text = nil
        end
      else
        -- Normal note grid (octaves 0-9)
        local note_name = note_names[col + 1]
        if string.find(note_name, "#") then
          note_text = note_name .. row  -- Sharp notes: "C#0", "D#1", etc. (no space)
        else
          note_text = note_name .. " " .. row  -- Natural notes: "C 0", "D 1", etc. (with space)
        end
      end
      
      -- Only draw if we have note text
      if note_text then
        local is_black_key = use_piano_keys and row < 10 and black_keys[col + 1]
        
        -- Choose colors based on preference
        local current_cell_color = is_black_key and black_key_color or white_key_color
        local current_text_color = is_black_key and text_color_black or text_color
        
        if is_hovered then
          current_cell_color = hover_color
          -- Invert text color on hover (match effect canvas behavior)
          if preferences.pakettiPlayerProEffectDialogDarkMode.value then
            current_text_color = {20, 20, 30, 255}  -- Dark text on white hover (same as effect canvas)
          else
            current_text_color = {255, 255, 255, 255}  -- White text on dark hover
          end
        end
        
        -- Draw cell background
        ctx.fill_color = current_cell_color
        ctx:fill_rect(x, y, note_cell_width, note_cell_height)
        
        -- Draw border
        ctx.stroke_color = border_color
        ctx.line_width = 1
        ctx:stroke_rect(x, y, note_cell_width, note_cell_height)
        
        -- Draw note text with dynamic centering in each cell
        ctx.stroke_color = current_text_color
        ctx.line_width = 1
        
        -- Special handling for "000" - add extra spacing between zeros
        if note_text == "000" then
          local text_size = 5
          local zero_width = text_size * 1.2
          local extra_spacing = 2  -- Extra pixels between zeros
          local total_width = (zero_width * 3) + (extra_spacing * 2)
          local start_x = x + (note_cell_width - total_width) / 2
          
          -- Draw each zero individually with extra spacing (vertically centered)
          local center_y = y + (note_cell_height - text_size) / 2
          draw_canvas_text(ctx, "0", start_x, center_y, text_size)
          draw_canvas_text(ctx, "0", start_x + zero_width + extra_spacing, center_y, text_size)
          draw_canvas_text(ctx, "0", start_x + (zero_width + extra_spacing) * 2, center_y, text_size)
        else
          -- Normal text centering
          local text_size = 5
          local letter_spacing = text_size * 1.2
          local text_width = #note_text * letter_spacing - (letter_spacing - text_size) -- Subtract last letter's extra spacing
          local centered_x = x + (note_cell_width - text_width) / 2
          
          -- Vertically center text in cell
          local center_y = y + (note_cell_height - text_size) / 2
          draw_canvas_text(ctx, note_text, centered_x, center_y, text_size)
        end
      end
    end
  end
end

function pakettiPlayerProNoteCanvasHandleMouse(ev, status_text_widget, canvas_widget, insert_function)
  -- Use provided parameters or fall back to default values
  local status_text = status_text_widget or note_status_text
  local canvas = canvas_widget or note_canvas
  local insert_func = insert_function or pakettiPlayerProNoteCanvasInsertNote
  
  local x = ev.position.x
  local y = ev.position.y
  
  -- Reset hover state
  note_hover_column = -1
  note_hover_row = -1
  
  -- Check if mouse is over the note grid
  if x >= 0 and x < note_canvas_width and y >= 0 and y < note_canvas_height then
    local col = math.floor(x / note_cell_width)
    local row = math.floor(y / note_cell_height)
    
    if col >= 0 and col < note_columns and row >= 0 and row < note_rows then
      -- Handle special bottom row (000, OFF)
      if row == 10 then
        if col == 0 then
          note_hover_column = col
          note_hover_row = row
          note_selected_note = "000"
          
          if status_text then
            status_text.text = "Note: 000 (Cut)"
          end
          
          -- Write on hover if enabled
          if preferences.pakettiPlayerProNoteCanvasWrite.value and ev.type == "move" then
            insert_func("000")
          end
          
          -- Handle click
          if ev.type == "down" then
            insert_func("000")
          end
        elseif col == 1 then
          note_hover_column = col
          note_hover_row = row
          note_selected_note = "OFF"
          
          if status_text then
            status_text.text = "Note: OFF"
          end
          
          -- Write on hover if enabled
          if preferences.pakettiPlayerProNoteCanvasWrite.value and ev.type == "move" then
            insert_func("OFF")
          end
          
          -- Handle click
          if ev.type == "down" then
            insert_func("OFF")
          end
        end
        -- Skip other columns in row 10
      else
        -- Normal note grid (octaves 0-9)
        note_hover_column = col
        note_hover_row = row
        
        -- Format note for Renoise: "C-0", "C#0", etc.
        local base_note = note_names[col + 1]
        local note_name
        if string.find(base_note, "#") then
          note_name = base_note .. row  -- Sharp notes: "C#0"
        else
          note_name = base_note .. "-" .. row  -- Natural notes: "C-0"
        end
        note_selected_note = note_name
        
        -- Update status text
        if status_text then
          status_text.text = "Note: " .. note_name
        end
        
        -- Write on hover if enabled
        if preferences.pakettiPlayerProNoteCanvasWrite.value and ev.type == "move" then
          insert_func(note_name)
        end
        
        -- Handle click (always writes regardless of Write mode)
        if ev.type == "down" then
          insert_func(note_name)
        end
      end
    end
  end
  
  -- Update canvas
  if canvas then
    canvas:update()
  end
end

function pakettiPlayerProNoteCanvasInsertNote(note)
  local song = renoise.song()
  local sel = song.selection_in_pattern
  local pattern_index = song.selected_pattern_index
  local note_to_insert = note == "000" and "---" or note
  local step = song.transport.edit_step
  
  if sel then
    -- Fill selection
    local start_track = sel.start_track
    local end_track = sel.end_track
    local start_line = sel.start_line
    local end_line = sel.end_line
    
    for track_index = start_track, end_track do
      local track = song:track(track_index)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        -- For EditStep mode with selection, first clear the entire selection, then write on EditStep lines
        if note_editstep_enabled then
          -- First pass: Clear the entire selection (both notes and instruments)
          for clear_line_index = start_line, end_line do
            local note_column = song:pattern(pattern_index):track(track_index):line(clear_line_index).note_columns[1]
            if note_column then
              note_column.note_string = "---"
              note_column.instrument_value = 255  -- Empty instrument
            end
          end
        end
        
        for line_index = start_line, end_line do
          if note_editstep_enabled then
            -- EditStep mode: write only on EditStep lines (selection already cleared above)
            if (line_index - start_line) % step == 0 then
              -- Write note on EditStep lines
              local note_column = song:pattern(pattern_index):track(track_index):line(line_index).note_columns[1]
              if note_column then
                note_column.note_string = note_to_insert
                if note == "000" or note == "OFF" then
                  note_column.instrument_value = 255  -- Empty instrument
                else
                  note_column.instrument_value = song.selected_instrument_index - 1
                end
              end
            end
            -- Note: non-EditStep lines remain cleared from first pass
          else
            -- Normal mode: fill all lines
            local note_column = song:pattern(pattern_index):track(track_index):line(line_index).note_columns[1]
            if note_column then
              note_column.note_string = note_to_insert
              if note == "000" or note == "OFF" then
                note_column.instrument_value = 255  -- Empty instrument
              else
                note_column.instrument_value = song.selected_instrument_index - 1
              end
            end
          end
        end
      end
    end
    renoise.app():show_status("Filled selection with " .. note .. (note_editstep_enabled and " (EditStep)" or ""))
  else
    -- Insert at current position
    local note_column = song.selected_note_column
    if note_column then
      note_column.note_string = note_to_insert
      if note == "000" or note == "OFF" then
        note_column.instrument_value = 255  -- Empty instrument
      else
        note_column.instrument_value = song.selected_instrument_index - 1
      end
      
      -- Advance edit position if EditStep is enabled
      if note_editstep_enabled and step > 0 then
        local new_line = song.selected_line_index + step
        
        -- Check if Spray mode is enabled and we would go beyond current pattern
        if preferences.pakettiPlayerProNoteCanvasSpray.value and new_line > song.selected_pattern.number_of_lines then
          -- Calculate how many lines we overshoot
          local overshoot = new_line - song.selected_pattern.number_of_lines
          
          -- Go to next pattern
          local next_pattern_index = song.selected_sequence_index + 1
          if next_pattern_index <= #song.sequencer.pattern_sequence then
            song.selected_sequence_index = next_pattern_index
            song.selected_line_index = overshoot
            -- Sprayed to next pattern (status handled by show_current_status)
          else
            -- Stay at the end of current pattern if no next pattern
            song.selected_line_index = song.selected_pattern.number_of_lines
            -- End of sequence reached (status handled by show_current_status)
          end
        else
          -- Normal behavior: stay within current pattern
          song.selected_line_index = math.min(new_line, song.selected_pattern.number_of_lines)
        end
      end
      
      -- Force status display regardless of monitor settings
      local song = renoise.song()
      local status_text = ""
      
      -- Check if we're in an effect column
      if song.selected_effect_column_index > 0 then
        local effect_column = song.selected_effect_column
        if effect_column and not effect_column.is_empty then
          local effect_number = effect_column.number_string
          local effect_value = effect_column.amount_value
          local effect_name = effect_names[effect_number]
          
          if effect_name then
            status_text = string.format("%s%02X - %s", 
                                       effect_number, effect_value, effect_name)
          else
            status_text = string.format("%s%02X", 
                                       effect_number, effect_value)
          end
        else
          status_text = "Effect Column: Empty"
        end
        
      -- Check if we're in a note column
      elseif song.selected_note_column_index > 0 then
        local note_column = song.selected_note_column
        if note_column then
          local parts = {}
          
          -- Note information
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
            if note_column.note_string == "OFF" then
              table.insert(parts, "Note: OFF")
            else
              table.insert(parts, string.format("Note: %s", note_column.note_string))
            end
          end
          
          -- Instrument information
          if note_column.instrument_value ~= renoise.PatternLine.EMPTY_INSTRUMENT then
            table.insert(parts, string.format("I:%02X", note_column.instrument_value))
          end
          
          -- Volume information
          if note_column.volume_value ~= renoise.PatternLine.EMPTY_VOLUME then
            table.insert(parts, string.format("Vol:%02X", note_column.volume_value))
          end
          
          -- Panning information
          if note_column.panning_value ~= renoise.PatternLine.EMPTY_PANNING then
            table.insert(parts, string.format("Pan:%02X", note_column.panning_value))
          end
          
          -- Delay information
          if note_column.delay_value ~= renoise.PatternLine.EMPTY_DELAY then
            table.insert(parts, string.format("Dly:%02X", note_column.delay_value))
          end
          
          -- Sample FX information
          if note_column.effect_number_value ~= renoise.PatternLine.EMPTY_EFFECT_NUMBER or
             note_column.effect_amount_value ~= renoise.PatternLine.EMPTY_EFFECT_AMOUNT then
            local fx_num = string.format("%02X", note_column.effect_number_value)
            table.insert(parts, string.format("FX:%s%02X", fx_num, note_column.effect_amount_value))
          end
          
          if #parts > 0 then
            status_text = table.concat(parts, " ")
          else
            status_text = "Empty"
          end
        end
      else
        status_text = "No column selected"
      end
      
      renoise.app():show_status(status_text)
    end
  end
  
  -- Keep pattern editor focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
local effect_items = {}  -- Make effect_items global

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
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

function pakettiPlayerProShowMainDialog()
  -- Check API version - use canvas version for v6.2+, traditional for older
  if renoise.API_VERSION >= 6.2 then
    pakettiPlayerProShowCanvasMainDialog()
  else
    pakettiPlayerProShowTraditionalMainDialog()
  end
end

-- Canvas-based Main Dialog for Renoise v6.2+ (combines note and effect canvases)
function pakettiPlayerProShowCanvasMainDialog()
  if main_canvas_dialog and main_canvas_dialog.visible then
    -- Clean up timer
    pakettiPlayerProEffectCanvasRemoveUpdateTimer()
    
    -- Clean up main canvas instrument observer
    if main_canvas_instrument_observer then
      PakettiPlayerProRemoveInstrumentObserver(main_canvas_instrument_observer)
      main_canvas_instrument_observer = nil
    end
    
    main_canvas_dialog:close()
    main_canvas_dialog = nil
    return
  end
  
  local vb = renoise.ViewBuilder()
  
  -- Create instrument items array
  local instrument_items = {"<None>"}
  for i = 0, #renoise.song().instruments - 1 do
    local instrument = renoise.song().instruments[i + 1]
    table.insert(instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
  end
  
  local selected_instrument_index = renoise.song().selected_instrument_index
  local selected_instrument_value = selected_instrument_index + 1
  
  -- Create note canvas
  main_note_canvas = vb:canvas {
    width = note_canvas_width,
    height = note_canvas_height,
    mode = "plain",
    render = pakettiPlayerProMainNoteCanvasDrawGrid,
    mouse_handler = pakettiPlayerProMainNoteCanvasHandleMouse,
    mouse_events = {"down", "up", "move", "exit"}
  }
  
  -- Create effect canvas
  main_effect_canvas = vb:canvas {
    width = canvas_width,
    height = canvas_height,
    mode = "plain",
    render = pakettiPlayerProMainEffectCanvasDrawEffect,
    mouse_handler = pakettiPlayerProMainEffectCanvasHandleMouse,
    mouse_events = {"down", "up", "move", "exit"}
  }
  
  -- No status text for note canvas (keep it minimal)
  main_note_status_text = nil
  
  -- Create status text for effect canvas only
  main_effect_status_text = vb:text {
    text = "00\n0",
    font = "mono",
    align = "center",
    width = canvas_width,
    tooltip = "Current hex value and decimal equivalent"
  }
  
  local dialog_content = vb:column {
    margin = 10,
    
    -- Title
    vb:text {
      text = "PlayerPro Canvas Tools",
      font = "big",
      style = "strong"
    },
    
    -- Instrument selector row
    vb:row {
      vb:text {
        text = "Instrument",
        style = "strong",
        font = "bold"
      },
      vb:popup {
        items = instrument_items,
        width = 320,
        id = "main_canvas_instrument_popup",
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
          print("Main Canvas Dialog - Instrument changed to: " .. tostring(instrument))
        end
      },
      vb:button {
        text = "Refresh",
        width = 100,
        notifier = function()
          local updated_instrument_items = {"<None>"}
          for i = 0, #renoise.song().instruments - 1 do
            local instrument = renoise.song().instruments[i + 1]
            table.insert(updated_instrument_items, string.format("%02X: %s", i, (instrument.name or "Untitled")))
          end
          if vb.views["main_canvas_instrument_popup"] then
            vb.views["main_canvas_instrument_popup"].items = updated_instrument_items
          end
        end
      }
    },
    
    -- Canvases side by side
    vb:row {
      -- Note canvas column
      vb:column {
        vb:text {
          text = "Notes",
          font = "bold",
          style = "strong",
          align = "center",
          width = note_canvas_width
        },
        main_note_canvas
      },
      
      -- Spacer
      vb:space { width = 20 },
      
      -- Effect canvas column
      vb:column {
        vb:text {
          text = "Effects",
          font = "bold",
          style = "strong",
          align = "center",
          width = canvas_width
        },
        main_effect_canvas,
        main_effect_status_text,
        
        -- Effect controls
        vb:row {
          vb:button {
            text = "CLR",
            width = 44,
            tooltip = "Clear effect column or subcolumn",
            notifier = function()
              local song = renoise.song()
              local column_info = ""
              
              -- Determine what to clear based on X mode
              if preferences.pakettiPlayerProEffectCanvasSubColumn.value then
                -- X mode enabled - clear specific subcolumn
                local sub_column_type = song.selected_sub_column_type
                
                if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear volume
                  column_info = " (Volume Column)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_PANNING then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "40")  -- Clear panning (center = 64 = 0x40)
                  column_info = " (Panning Column)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_DELAY then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear delay
                  column_info = " (Delay Column)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear sample fx amount
                  column_info = " (Sample FX Amount)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear sample fx number
                  column_info = " (Sample FX Number)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_NUMBER then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear effect number
                  column_info = " (Effect Number)"
                elseif sub_column_type == renoise.Song.SUB_COLUMN_EFFECT_AMOUNT then
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Clear effect amount
                  column_info = " (Effect Amount)"
                else
                  pakettiPlayerProCanvasWriteEffectToPattern("00", "00")  -- Fallback
                  column_info = " (Unknown Column)"
                end
              else
                -- Normal mode - clear effect column
                pakettiPlayerProCanvasWriteEffectToPattern("00", "00")
                column_info = " (Effect Column)"
              end
              
              -- Reset selection display
              selected_x = 0
              selected_y = 0
              if main_effect_canvas then
                main_effect_canvas:update()
              end
              if main_effect_status_text then
                main_effect_status_text.text = format_effect_status("00", 0)
              end
              
              renoise.app():show_status("Cleared 00" .. column_info)
            end
          }
        },
        vb:row {
          vb:checkbox {
            value = preferences.pakettiPlayerProEffectCanvasWrite.value,
            tooltip = "Write on hover when enabled, otherwise click to write",
            notifier = function(value)
              preferences.pakettiPlayerProEffectCanvasWrite.value = value
              preferences:save_as("preferences.xml")
            end
          },
          vb:text {
            text = "W"
          },
          vb:checkbox {
            value = preferences.pakettiPlayerProEffectCanvasSubColumn.value,
            tooltip = "Auto-detect subcolumn (effect number/amount) when enabled",
            notifier = function(value)
              preferences.pakettiPlayerProEffectCanvasSubColumn.value = value
            end
          },
          vb:text {
            text = "X"
          }
        }
      }
    },
    
    -- Global controls
    vb:row {
      vb:button {
        text = preferences.pakettiPlayerProEffectDialogDarkMode.value and "Light" or "Dark",
        width = 60,
        tooltip = "PlayerPro Dark or Light Mode",
        notifier = function()
          preferences.pakettiPlayerProEffectDialogDarkMode.value = not preferences.pakettiPlayerProEffectDialogDarkMode.value
          
          -- Update both canvases
          if main_note_canvas then
            main_note_canvas:update()
          end
          if main_effect_canvas then
            main_effect_canvas:update()
          end
          
          -- Close and reopen dialog to update button text
          if main_canvas_dialog then
            -- Clean up timer before closing
            pakettiPlayerProEffectCanvasRemoveUpdateTimer()
            
            -- Clean up main canvas instrument observer
            if main_canvas_instrument_observer then
              PakettiPlayerProRemoveInstrumentObserver(main_canvas_instrument_observer)
              main_canvas_instrument_observer = nil
            end
            
            main_canvas_dialog:close()
            main_canvas_dialog = nil
          end
          pakettiPlayerProShowCanvasMainDialog()
        end
      },
      vb:button {
        text = "Close",
        width = 60,
        notifier = function()
          -- Clean up timer
          pakettiPlayerProEffectCanvasRemoveUpdateTimer()
          
          -- Clean up main canvas instrument observer
          if main_canvas_instrument_observer then
            PakettiPlayerProRemoveInstrumentObserver(main_canvas_instrument_observer)
            main_canvas_instrument_observer = nil
          end
          
          if main_canvas_dialog then
            main_canvas_dialog:close()
            main_canvas_dialog = nil
          end
        end
      }
    }
  }
  
  local keyhandler = my_keyhandler_func
  main_canvas_dialog = renoise.app():show_custom_dialog("PlayerPro Canvas Tools", dialog_content, keyhandler)
  
  -- Add instrument observer after dialog is created
  main_canvas_instrument_observer = PakettiPlayerProCreateInstrumentObserver(vb, "main_canvas_instrument_popup", main_canvas_dialog)
  
  -- Set focus to pattern editor
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  
  -- Setup canvas update timer for automatic subcolumn detection (for effect canvas)
  pakettiPlayerProEffectCanvasSetupUpdateTimer()
end

-- Main note canvas drawing function (same as individual dialog but uses main_note_status_text)
function pakettiPlayerProMainNoteCanvasDrawGrid(ctx, w, h)
  pakettiPlayerProNoteCanvasDrawGrid(ctx, w, h)
end

-- Main note canvas mouse handler (reuses the original logic with main status text)
function pakettiPlayerProMainNoteCanvasHandleMouse(ev)
  pakettiPlayerProNoteCanvasHandleMouse(ev, main_note_status_text, main_note_canvas, pakettiPlayerProMainNoteCanvasInsertNote)
end

-- Main note insertion function (reuses the original note insertion logic)
function pakettiPlayerProMainNoteCanvasInsertNote(note)
  pakettiPlayerProNoteCanvasInsertNote(note)
end

-- Main effect canvas drawing function (same as individual dialog but uses main canvas variables)
function pakettiPlayerProMainEffectCanvasDrawEffect(ctx, w, h)
  pakettiPlayerProCanvasDrawEffect(ctx, w, h)
end

-- Main effect canvas mouse handler (same as individual dialog but uses main_effect_status_text)
function pakettiPlayerProMainEffectCanvasHandleMouse(ev)
  pakettiPlayerProCanvasHandleMouse(ev, main_effect_status_text, main_effect_canvas)
end

function pakettiPlayerProShowTraditionalMainDialog()
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
  effect_items = {"None"}
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

  -- Function moved outside to global scope

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
    
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
  end

  -- Function moved to global scope

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
          renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Player Pro Main Dialog", dialog_content, keyhandler)
  
  -- Add instrument observer after dialog is created
  main_dialog_instrument_observer = PakettiPlayerProCreateInstrumentObserver(main_vb, "main_dialog_instrument_popup", dialog)
  
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
    
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
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
  else
    -- Show current note column status after insertion
    show_current_status()
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


-- Global variables for the always open system
local always_open_observers = {}
local always_open_current_context = nil
local always_open_last_cursor_state = nil
local always_open_timer = nil

-- Middle Frame Observer for Auto-Hide
local middle_frame_observer = nil
local last_middle_frame = nil

function pakettiPlayerProStartMiddleFrameObserver()
  if middle_frame_observer then
    return -- Already running
  end
  
  -- Initialize last frame state
  last_middle_frame = renoise.app().window.active_middle_frame
  
  middle_frame_observer = function()
    local current_frame = renoise.app().window.active_middle_frame
    
    -- Safety check: if last_middle_frame is nil (tool just loaded), 
    -- just initialize and don't open any dialogs
    if last_middle_frame == nil then
      last_middle_frame = current_frame
      return
    end
    
    -- Only act on actual frame changes
    if current_frame == last_middle_frame then
      return
    end
    
    -- Leaving Pattern Editor - close dialogs (only if auto-hide is enabled)
    if preferences.pakettiPlayerProAutoHideOnFrameSwitch.value and
       last_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR and 
       current_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      
      if note_canvas_dialog and note_canvas_dialog.visible then
        note_canvas_dialog:close()
        note_canvas_dialog = nil
      end
      if dialog and dialog.visible then
        dialog:close()
        dialog = nil
      end
      if effect_canvas_dialog and effect_canvas_dialog.visible then
        effect_canvas_dialog:close()
        effect_canvas_dialog = nil
      end
      if effect_dialog and effect_dialog.visible then
        effect_dialog:close()
        effect_dialog = nil
      end
    
    -- Entering Pattern Editor - ALWAYS open appropriate dialog (if always open is enabled)
    elseif preferences.pakettiPlayerProAlwaysOpen.value and
           last_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR and 
           current_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
      
      local context = pakettiPlayerProGetCurrentContext()
      local context_type, track_index, column_index = context:match("([^:]+):([^:]+):([^:]+)")
      
      -- Always show current status when entering Pattern Editor
      local song = renoise.song()
      local status_text = ""
      
      -- Check if we're in an effect column
      if song.selected_effect_column_index > 0 then
        local effect_column = song.selected_effect_column
        if effect_column and not effect_column.is_empty then
          local effect_number = effect_column.number_string
          local effect_value = effect_column.amount_value
          local effect_name = effect_names[effect_number]
          
          if effect_name then
            status_text = string.format("%s%02X - %s", 
                                       effect_number, effect_value, effect_name)
          else
            status_text = string.format("%s%02X", 
                                       effect_number, effect_value)
          end
        else
          status_text = "Effect Column: Empty"
        end
        
      -- Check if we're in a note column
      elseif song.selected_note_column_index > 0 then
        local note_column = song.selected_note_column
        if note_column then
          local parts = {}
          
          -- Note information
          if note_column.note_value ~= renoise.PatternLine.EMPTY_NOTE then
            if note_column.note_string == "OFF" then
              table.insert(parts, "Note: OFF")
            else
              table.insert(parts, string.format("Note: %s", note_column.note_string))
            end
          end
          
          -- Instrument information
          if note_column.instrument_value ~= renoise.PatternLine.EMPTY_INSTRUMENT then
            table.insert(parts, string.format("I:%02X", note_column.instrument_value))
          end
          
          -- Volume information
          if note_column.volume_value ~= renoise.PatternLine.EMPTY_VOLUME then
            table.insert(parts, string.format("Vol:%02X", note_column.volume_value))
          end
          
          -- Panning information
          if note_column.panning_value ~= renoise.PatternLine.EMPTY_PANNING then
            table.insert(parts, string.format("Pan:%02X", note_column.panning_value))
          end
          
          -- Delay information
          if note_column.delay_value ~= renoise.PatternLine.EMPTY_DELAY then
            table.insert(parts, string.format("Dly:%02X", note_column.delay_value))
          end
          
          -- Sample FX information
          if note_column.effect_number_value ~= renoise.PatternLine.EMPTY_EFFECT_NUMBER or
             note_column.effect_amount_value ~= renoise.PatternLine.EMPTY_EFFECT_AMOUNT then
            local fx_num = string.format("%02X", note_column.effect_number_value)
            table.insert(parts, string.format("FX:%s%02X", fx_num, note_column.effect_amount_value))
          end
          
          if #parts > 0 then
            status_text = table.concat(parts, " ")
          else
            status_text = "Empty"
          end
        end
      else
        status_text = "No column selected"
      end
      
      renoise.app():show_status(status_text)
      
      -- Always open appropriate dialog based on context
      if context_type == "note" then
        -- Determine if we're in a subcolumn that should open effect dialog
        if preferences.pakettiPlayerProSmartSubColumn.value then
          local sub_column_type = song.selected_sub_column_type
          if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME or 
             sub_column_type == renoise.Song.SUB_COLUMN_PANNING or 
             sub_column_type == renoise.Song.SUB_COLUMN_DELAY or 
             sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER then
            -- Open effect dialog for subcolumns
            if renoise.API_VERSION >= 6.2 then
              pakettiPlayerProEffectDialogCanvas()
            else
              pakettiPlayerProEffectDialogTraditional()
            end
            renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
            last_middle_frame = current_frame
            return
          end
        end
        
        -- Open note dialog
        if renoise.API_VERSION >= 6.2 then
          pakettiPlayerProNoteGridShowCanvasGrid()
        else
          pakettiPlayerProNoteGridShowTraditionalGrid()
        end
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        
      elseif context_type == "effect" then
        -- Open effect dialog
        if renoise.API_VERSION >= 6.2 then
          pakettiPlayerProEffectDialogCanvas()
        else
          pakettiPlayerProEffectDialogTraditional()
        end
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      end
    end
    
    -- Update last frame state
    last_middle_frame = current_frame
  end
  
  renoise.app().window.active_middle_frame_observable:add_notifier(middle_frame_observer)
  print("PlayerPro: Started middle frame observer")
end

function pakettiPlayerProStopMiddleFrameObserver()
  if middle_frame_observer then
    pcall(function()
      if renoise.app().window.active_middle_frame_observable:has_notifier(middle_frame_observer) then
        renoise.app().window.active_middle_frame_observable:remove_notifier(middle_frame_observer)
      end
    end)
    middle_frame_observer = nil
    print("PlayerPro: Stopped middle frame observer")
  end
end

-- Function to determine current pattern editor context with full cursor state
function pakettiPlayerProGetCurrentContext()
  local song = renoise.song()
  local selected_track = song.selected_track
  
  -- Only handle sequencer tracks
  if selected_track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
    return "none"
  end
  
  -- Create full context including track/column position
  local track_index = song.selected_track_index
  local note_column_index = song.selected_note_column_index
  local effect_column_index = song.selected_effect_column_index
  local sub_column_type = song.selected_sub_column_type
  
  -- Check if we're in an effect column
  if effect_column_index > 0 then
    return "effect:" .. track_index .. ":" .. effect_column_index
  end
  
  -- Check if smart subcolumn is enabled and we're in a non-note subcolumn
  if preferences.pakettiPlayerProSmartSubColumn and preferences.pakettiPlayerProSmartSubColumn.value then
    if sub_column_type == renoise.Song.SUB_COLUMN_VOLUME or
       sub_column_type == renoise.Song.SUB_COLUMN_PANNING or
       sub_column_type == renoise.Song.SUB_COLUMN_DELAY or
       sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_NUMBER or
       sub_column_type == renoise.Song.SUB_COLUMN_SAMPLE_EFFECT_AMOUNT then
      return "effect:" .. track_index .. ":" .. note_column_index .. ":" .. sub_column_type
    end
  end
  
  -- Default to note context with position
  return "note:" .. track_index .. ":" .. note_column_index
end

-- Timer function to monitor cursor position changes
function pakettiPlayerProTimerContextMonitor()
  -- Only monitor if always open is enabled
  if not preferences.pakettiPlayerProAlwaysOpen or not preferences.pakettiPlayerProAlwaysOpen.value then
    return
  end
  
  -- Safe song access with error handling
  local song
  local success, error_msg = pcall(function()
    song = renoise.song()
  end)
  
  if not success or not song or not song.selected_track then
    return
  end
  
  -- Only monitor if we're in pattern editor
  if renoise.app().window.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR then
    return
  end
  
  -- Get current cursor state
  local track_index = song.selected_track_index
  local note_column_index = song.selected_note_column_index
  local effect_column_index = song.selected_effect_column_index
  local sub_column_type = song.selected_sub_column_type
  
  -- Create state hash for comparison
  local current_state = track_index .. ":" .. note_column_index .. ":" .. effect_column_index .. ":" .. sub_column_type
  
  -- Check if cursor state changed
  if current_state ~= always_open_last_cursor_state then
    print("DEBUG: Cursor state changed from '" .. tostring(always_open_last_cursor_state) .. "' to '" .. current_state .. "'")
    always_open_last_cursor_state = current_state
    pakettiPlayerProHandleContextChange()
  end
end

-- Function to handle context changes
function pakettiPlayerProHandleContextChange()
  if not preferences.pakettiPlayerProAlwaysOpen or not preferences.pakettiPlayerProAlwaysOpen.value then
    return
  end
  
  local new_context = pakettiPlayerProGetCurrentContext()
  
  print("DEBUG: Context changed from '" .. tostring(always_open_current_context) .. "' to '" .. new_context .. "'")
  
  -- Only act if context actually changed
  if new_context == always_open_current_context then
    print("DEBUG: Context unchanged, skipping")
    return
  end
  
  always_open_current_context = new_context
  
  -- Parse context type (note:track:column or effect:track:column)
  local context_type = new_context:match("^([^:]+)")
  
  if context_type == "note" then
    -- Close effect dialog if open, open note dialog
    if effect_canvas_dialog and effect_canvas_dialog.visible then
      effect_canvas_dialog:close()
      effect_canvas_dialog = nil
    end
    if effect_dialog and effect_dialog.visible then
      effect_dialog:close()
      effect_dialog = nil
    end
    
    -- Open note dialog (always ensure it's open when in note context)
    if renoise.API_VERSION >= 6.2 then
      if not note_canvas_dialog or not note_canvas_dialog.visible then
        pakettiPlayerProNoteGridShowCanvasGrid()
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        show_current_status()
      end
    else
      if not dialog or not dialog.visible then
        pakettiPlayerProNoteGridShowTraditionalGrid()
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        show_current_status()
      end
    end
    
  elseif context_type == "effect" then
    -- Close note dialog if open, open effect dialog
    if note_canvas_dialog and note_canvas_dialog.visible then
      note_canvas_dialog:close()
      note_canvas_dialog = nil
    end
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
    end
    
    -- Open effect dialog (check if not already open)
    if not effect_canvas_dialog or not effect_canvas_dialog.visible then
      if not effect_dialog or not effect_dialog.visible then
        pakettiPlayerProEffectDialog()
        renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
        show_current_status()
      end
    end
    
  elseif context_type == "none" then
    -- Close all dialogs for non-sequencer tracks
    if note_canvas_dialog and note_canvas_dialog.visible then
      note_canvas_dialog:close()
      note_canvas_dialog = nil
    end
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
    end
    if effect_canvas_dialog and effect_canvas_dialog.visible then
      effect_canvas_dialog:close()
      effect_canvas_dialog = nil
    end
    if effect_dialog and effect_dialog.visible then
      effect_dialog:close()
      effect_dialog = nil
    end
  end
  
  -- Ensure focus returns to Renoise after any dialog operations
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-- Function to start the always open system
function pakettiPlayerProStartAlwaysOpen()
  pakettiPlayerProStopAlwaysOpen()  -- Clean up any existing observers
  
  local song = renoise.song()
  
  -- Add observers for track changes only
  if not song.selected_track_index_observable:has_notifier(pakettiPlayerProHandleContextChange) then
    song.selected_track_index_observable:add_notifier(pakettiPlayerProHandleContextChange)
    table.insert(always_open_observers, {observable = song.selected_track_index_observable, func = pakettiPlayerProHandleContextChange})
  end
  
  -- Start timer to monitor cursor position changes (note/effect column changes and subcolumns)
  if not always_open_timer then
    always_open_timer = renoise.tool():add_timer(pakettiPlayerProTimerContextMonitor, 100) -- Check every 100ms
  end
  
  -- Initialize current context and open appropriate dialog
  always_open_current_context = nil
  always_open_last_cursor_state = nil -- Reset cursor state
  pakettiPlayerProHandleContextChange()
  
  renoise.app():show_status("PlayerPro Always Open Dialog: Enabled")
end

-- Function to stop the always open system
function pakettiPlayerProStopAlwaysOpen()
  -- Remove all observers with safety checks
  for _, observer_info in ipairs(always_open_observers) do
    -- Safety check: ensure observable still exists before accessing it
    local success, has_notifier = pcall(function()
      return observer_info.observable and observer_info.observable:has_notifier(observer_info.func)
    end)
    
    if success and has_notifier then
      local remove_success = pcall(function()
        observer_info.observable:remove_notifier(observer_info.func)
      end)
      if not remove_success then
        print("PlayerPro Always Open: Warning - Could not remove observer (observable may be nil)")
      end
    end
  end
  always_open_observers = {}
  
  -- Stop timer if running
  if always_open_timer then
    renoise.tool():remove_timer(pakettiPlayerProTimerContextMonitor)
    always_open_timer = nil
  end
  
  always_open_current_context = nil
  always_open_last_cursor_state = nil
  
  renoise.app():show_status("PlayerPro Always Open Dialog: Disabled")
end

-- Initialize always open system on startup if preference is enabled
function pakettiPlayerProInitializeAlwaysOpen()
  if preferences.pakettiPlayerProAlwaysOpen and preferences.pakettiPlayerProAlwaysOpen.value then
    pakettiPlayerProStartAlwaysOpen()
  end
  
  -- Always start middle frame observer (it checks the preference internally)
  pakettiPlayerProStartMiddleFrameObserver()
end
