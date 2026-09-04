-- PakettiExecute.lua
-- FEATURE-CARD >> features/execute-command-slots.feature
-- Configurable os.execute() command slots for keybindings and MIDI mappings.

local vb = renoise.ViewBuilder()
local dialog = nil
local EXECUTE_SLOT_COUNT = 128

local function slot_key(slot_number, suffix)
  return string.format("Slot%03d%s", slot_number, suffix)
end

local function legacy_key(slot_number, suffix)
  return string.format("App%02d%s", slot_number, suffix or "")
end

local function shell_quote(value)
  value = tostring(value or "")
  if os.platform() == "WINDOWS" then
    return '"' .. value:gsub('"', '""') .. '"'
  end
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function basename(path)
  local name = tostring(path or ""):gsub("\\", "/"):match("([^/]+)$")
  return name or ""
end

local function save_preferences()
  renoise.tool().preferences:save_as("preferences.xml")
end

local function get_slot_preferences(slot_number)
  if not PakettiExecute then return nil, nil end
  return PakettiExecute[slot_key(slot_number, "Label")],
    PakettiExecute[slot_key(slot_number, "Command")]
end

local function build_legacy_command(app_path, arguments)
  local args = arguments or ""
  if os.platform() == "MACINTOSH" and app_path:match("%.app/?$") then
    local command = "open -a " .. shell_quote(app_path)
    if args ~= "" then command = command .. " --args " .. args end
    return command
  end

  local command = shell_quote(app_path)
  if args ~= "" then command = command .. " " .. args end
  return command
end

local function migrate_legacy_slot(slot_number)
  if slot_number > 10 then return end

  local label_pref, command_pref = get_slot_preferences(slot_number)
  if not label_pref or not command_pref or command_pref.value ~= "" then return end

  local app_pref = PakettiExecute[legacy_key(slot_number)]
  local arg_pref = PakettiExecute[legacy_key(slot_number, "Argument")]
  if not app_pref or app_pref.value == "" then return end

  label_pref.value = label_pref.value ~= "" and label_pref.value or basename(app_pref.value)
  command_pref.value = build_legacy_command(app_pref.value, arg_pref and arg_pref.value or "")
  save_preferences()
end

local function get_slot_label(slot_number)
  migrate_legacy_slot(slot_number)
  local label_pref = get_slot_preferences(slot_number)
  if label_pref and label_pref.value ~= "" then
    return label_pref.value
  end
  return string.format("Slot %03d", slot_number)
end

local function get_slot_command(slot_number)
  migrate_legacy_slot(slot_number)
  local _, command_pref = get_slot_preferences(slot_number)
  return command_pref and command_pref.value or ""
end

local function set_slot_label(slot_number, label)
  local label_pref = get_slot_preferences(slot_number)
  if label_pref then
    label_pref.value = label or ""
    save_preferences()
  end
end

local function set_slot_command(slot_number, command)
  local _, command_pref = get_slot_preferences(slot_number)
  if command_pref then
    command_pref.value = command or ""
    save_preferences()
  end
end

local function slot_display_name(slot_number)
  local label = get_slot_label(slot_number)
  local command = get_slot_command(slot_number)
  if command == "" and label == string.format("Slot %03d", slot_number) then
    return string.format("%03d - (empty)", slot_number)
  end
  return string.format("%03d - %s", slot_number, label)
end

local function slot_popup_items()
  local items = {}
  for i = 1, EXECUTE_SLOT_COUNT do
    table.insert(items, slot_display_name(i))
  end
  return items
end

local function selected_sample_range()
  local song = renoise.song()
  local sample = song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    return nil, "No selected sample with sample data for $s"
  end

  local buffer = sample.sample_buffer
  local selection = buffer.selection_range
  local selection_start = selection and selection[1] or buffer.selection_start
  local selection_end = selection and selection[2] or buffer.selection_end

  if not selection_start or not selection_end or selection_start >= selection_end then
    return nil, "Select a sample range before running a command that uses $s"
  end

  return {
    buffer = buffer,
    start_frame = selection_start,
    end_frame = selection_end,
    frame_count = selection_end - selection_start + 1
  }
end

local function temp_wav_path(slot_number)
  local suffix = string.format("paketti-execute-slot-%03d-%d.wav", slot_number, os.time())
  local sep = package.config:sub(1, 1)
  local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or os.getenv("TMP") or "/tmp"
  if tmp:sub(-1) == "/" or tmp:sub(-1) == "\\" then
    return tmp .. suffix
  end
  return tmp .. sep .. suffix
end

local function export_selected_range(slot_number)
  local range, err = selected_sample_range()
  if not range then return nil, err end

  if type(canInsertInstrument) == "function" and not canInsertInstrument() then
    return nil, "Cannot create temporary sample: maximum instrument count reached"
  end

  local song = renoise.song()
  local original_instrument_index = song.selected_instrument_index
  local original_sample_index = song.selected_sample_index
  local temp_index = #song.instruments + 1
  local monitoring_state = nil
  if type(PakettiTemporarilyDisableNewSampleMonitoring) == "function" then
    monitoring_state = PakettiTemporarilyDisableNewSampleMonitoring()
  end

  local path = temp_wav_path(slot_number)
  local ok, result = pcall(function()
    local temp_instrument = song:insert_instrument_at(temp_index)
    temp_instrument.name = "Paketti Execute Temp"
    local temp_sample = temp_instrument:insert_sample_at(1)
    local temp_buffer = temp_sample.sample_buffer
    local source = range.buffer

    temp_buffer:create_sample_data(
      source.sample_rate,
      source.bit_depth,
      source.number_of_channels,
      range.frame_count
    )
    temp_buffer:prepare_sample_data_changes()
    for channel = 1, source.number_of_channels do
      for frame = 1, range.frame_count do
        temp_buffer:set_sample_data(channel, frame, source:sample_data(channel, range.start_frame + frame - 1))
      end
    end
    temp_buffer:finalize_sample_data_changes()
    temp_buffer:save_as(path, "wav")
    return path
  end)

  if #song.instruments >= temp_index then
    pcall(function() song:delete_instrument_at(temp_index) end)
  end
  if original_instrument_index <= #song.instruments then
    song.selected_instrument_index = original_instrument_index
    if original_sample_index and original_sample_index <= #song.selected_instrument.samples then
      song.selected_sample_index = original_sample_index
    end
  end
  if type(PakettiRestoreNewSampleMonitoring) == "function" then
    PakettiRestoreNewSampleMonitoring(monitoring_state)
  end

  if not ok then
    return nil, "Could not export selected sample range: " .. tostring(result)
  end
  return result
end

local function command_with_selected_sample(command, slot_number)
  if not command:find("$s", 1, true) then
    return command
  end

  local path, err = export_selected_range(slot_number)
  if not path then return nil, err end

  if os.platform() == "WINDOWS" then
    return 'set "s=' .. path:gsub('"', '""') .. '" && ' .. command:gsub("%$s", "%%s%%"), path
  end

  return "s=" .. shell_quote(path) .. "; export s; " .. command, path
end

function PakettiExecuteRunCommand(command, label, slot_number)
  if not command or command == "" then
    renoise.app():show_status("Paketti Execute: empty command slot " .. string.format("%03d", slot_number or 0))
    return false
  end

  local executable_command, sample_path = command_with_selected_sample(command, slot_number or 0)
  if not executable_command then
    renoise.app():show_status("Paketti Execute: " .. tostring(sample_path))
    return false
  end

  print("PakettiExecute: os.execute(" .. executable_command .. ")")
  local result = os.execute(executable_command)
  local success = result == true or result == 0
  local name = label and label ~= "" and label or ("slot " .. string.format("%03d", slot_number or 0))

  if success then
    local suffix = sample_path and (" ($s = " .. sample_path .. ")") or ""
    renoise.app():show_status("Paketti Execute: ran " .. name .. suffix)
  else
    renoise.app():show_status("Paketti Execute failed: " .. name)
  end
  return success
end

function PakettiExecuteRunSlot(slot_number)
  if not slot_number or slot_number < 1 or slot_number > EXECUTE_SLOT_COUNT then
    renoise.app():show_status("Paketti Execute: invalid slot number")
    return false
  end

  local command = get_slot_command(slot_number)
  if command == "" then
    renoise.app():show_status("Paketti Execute: slot " .. string.format("%03d", slot_number) .. " is empty")
    return false
  end

  return PakettiExecuteRunCommand(command, get_slot_label(slot_number), slot_number)
end

function PakettiExecuteShowDialog()
  if dialog and dialog.visible then
    dialog:close()
    return
  end

  local selected_slot = 1
  local slot_popup = nil
  local label_field = nil
  local command_field = nil

  local function refresh_fields()
    label_field.text = get_slot_label(selected_slot)
    command_field.text = get_slot_command(selected_slot)
  end

  local function refresh_popup()
    slot_popup.items = slot_popup_items()
    slot_popup.value = selected_slot
  end

  slot_popup = vb:popup{
    items = slot_popup_items(),
    value = selected_slot,
    width = 300,
    notifier = function(value)
      selected_slot = value
      refresh_fields()
    end
  }

  label_field = vb:textfield{
    text = get_slot_label(selected_slot),
    width = 440,
    notifier = function(text)
      set_slot_label(selected_slot, text)
      refresh_popup()
    end
  }

  command_field = vb:textfield{
    text = get_slot_command(selected_slot),
    width = 640,
    tooltip = "Shell command passed to os.execute(). Use $s to export the selected sample range to a temporary WAV before running.",
    notifier = function(text)
      set_slot_command(selected_slot, text)
    end
  }

  local dialog_content = vb:column{
    margin = 10,
    spacing = 8,
    vb:row{
      spacing = 8,
      vb:text{text = "Slot", width = 70, style = "strong", font = "bold"},
      slot_popup
    },
    vb:row{
      spacing = 8,
      vb:text{text = "Label", width = 70, style = "strong", font = "bold"},
      label_field
    },
    vb:row{
      spacing = 8,
      vb:text{text = "Command", width = 70, style = "strong", font = "bold"},
      command_field
    },
    vb:row{
      spacing = 8,
      vb:space{width = 70},
      vb:button{
        text = "Browse...",
        width = 90,
        notifier = function()
          local file_path = renoise.app():prompt_for_filename_to_read({"*"}, "Select Executable or Script for Execute Slot " .. string.format("%03d", selected_slot))
          if file_path and file_path ~= "" then
            local quoted = shell_quote(file_path)
            command_field.text = quoted
            set_slot_command(selected_slot, quoted)
            if label_field.text == "" or label_field.text == string.format("Slot %03d", selected_slot) then
              label_field.text = basename(file_path)
              set_slot_label(selected_slot, label_field.text)
            end
            refresh_popup()
          end
        end
      },
      vb:button{
        text = "Run",
        width = 70,
        notifier = function()
          set_slot_label(selected_slot, label_field.text)
          set_slot_command(selected_slot, command_field.text)
          refresh_popup()
          PakettiExecuteRunSlot(selected_slot)
        end
      },
      vb:button{
        text = "Clear",
        width = 70,
        notifier = function()
          label_field.text = ""
          command_field.text = ""
          set_slot_label(selected_slot, "")
          set_slot_command(selected_slot, "")
          refresh_popup()
        end
      },
      vb:button{
        text = "Close",
        width = 70,
        notifier = function()
          dialog:close()
        end
      }
    },
  }

  dialog = renoise.app():show_custom_dialog("Paketti Execute Commands", dialog_content, my_keyhandler_func)
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Show Execute Commands Dialog...",
  invoke = PakettiExecuteShowDialog
}

for i = 1, EXECUTE_SLOT_COUNT do
  local slot = i
  local slot_name = string.format("%03d", slot)
  renoise.tool():add_keybinding{
    name = "Global:Paketti:Execute Command Slot " .. slot_name,
    invoke = function() PakettiExecuteRunSlot(slot) end
  }
  renoise.tool():add_midi_mapping{
    name = "Paketti:Execute Command Slot " .. slot_name .. " [Trigger]",
    invoke = function(message)
      if message:is_trigger() then
        PakettiExecuteRunSlot(slot)
      end
    end
  }
end
