-- PakettiDynamicViews.lua

-- Declare DynamicViewPrefs before using it
local DynamicViewPrefs

-- Set the number of dynamic views
local dynamic_views_count = 8
local steps_per_view = 8

local views_upper = {
  {frame = renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES, label = "Track Scopes"},
  {frame = renoise.ApplicationWindow.UPPER_FRAME_MASTER_SPECTRUM, label = "Master Spectrum"}
}

local views_middle = {
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR, label = "Pattern Editor"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER, label = "Mixer"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR, label = "Phrase Editor"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES, label = "Sample Keyzones"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR, label = "Sample Editor"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION, label = "Sample Modulation"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS, label = "Sample Effects"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR, label = "Plugin Editor"},
  {frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR, label = "MIDI Editor"}
}

local views_lower = {
  {frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS, label = "Track DSPs"},
  {frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION, label = "Track Automation"}
}

-- Restricted middle frames that force the lower frame to hide
local restricted_middle_frames = { 
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
}

-- Middle frames that disable Pattern Matrix and Advanced Editor
local disable_pattern_matrix_advanced_edit_middle_frames = {
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR,
  renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR
}

-- Mixer frame that disables Advanced Editor
local disable_advanced_edit_mixer_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER

-- Current step tracker for each dynamic view
local current_steps = {}
for i = 1, dynamic_views_count do
  current_steps[i] = 0 -- Start with step 0 for each dynamic view
end

-- Last cycled time tracker for debounce
local last_cycled_time = {}
for i = 1, dynamic_views_count do
  last_cycled_time[i] = 0
end

-- Global dialog variable to track open dialogs
local dialog = nil

-- Path to preferences file for saving/loading
local prefs_file = renoise.tool().bundle_path .. "preferencesDynamicView.xml"

-- Create observable preferences for Paketti Dynamic Views
if not DynamicViewPrefs then
  DynamicViewPrefs = renoise.Document.create("PakettiDynamicViewsPreferences") {}
  for dv = 1, dynamic_views_count do
    local dv_id = string.format("%02d", dv)
    for step = 1, steps_per_view do
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_upper_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_middle_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_lower_step" .. step, renoise.Document.ObservableNumber(1))

      -- Update properties to use ObservableNumber instead of ObservableBoolean
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_instrument_box_slot_size_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_instrument_editor_detached_step" .. step, renoise.Document.ObservableNumber(1))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_mixer_view_detached_step" .. step, renoise.Document.ObservableNumber(1))
    end
  end
end

-- Load preferences from XML file
function loadDynamicViewPreferences()
  if io.exists(prefs_file) then
    DynamicViewPrefs:load_from(prefs_file)
  end

  -- Ensure all properties are initialized
  for dv = 1, dynamic_views_count do
    local dv_id = string.format("%02d", dv)
    for step = 1, steps_per_view do
      local prop_names = {
        "upper_step", "middle_step", "lower_step",
        "sample_record_visible_step", "disk_browser_visible_step",
        "instrument_box_visible_step", "instrument_box_slot_size_step", "pattern_matrix_visible_step",
        "pattern_advanced_edit_visible_step", "instrument_editor_detached_step",
        "mixer_view_detached_step"
      }
      for _, prop_suffix in ipairs(prop_names) do
        local prop_name = "dynamic_view" .. dv_id .. "_" .. prop_suffix .. step
        if not DynamicViewPrefs:property(prop_name) then
          -- Adjust default value to be 1 (i.e., "<Change Nothing>")
          DynamicViewPrefs:add_property(prop_name, renoise.Document.ObservableNumber(1))
        end
      end
    end
  end
end

-- Save preferences to XML file
function saveDynamicViewPreferences()
  DynamicViewPrefs:save_as(prefs_file)
end

-- Load preferences when the tool is initialized
loadDynamicViewPreferences()

-- Function to check if the middle frame should disable both Pattern Matrix and Advanced Editor
local function disable_pattern_matrix_and_advanced_edit(middle_frame)
  for _, frame in ipairs(disable_pattern_matrix_advanced_edit_middle_frames) do
    if middle_frame == frame then
      return true
    end
  end
  return false
end

-- Function to check if the middle frame is restricted
local function is_restricted_middle_frame(middle_frame)
  for _, restricted_frame in ipairs(restricted_middle_frames) do
    if middle_frame == restricted_frame then
      return true
    end
  end
  return false
end

-- Function to build dropdown options for a given view list
local function build_options(view_list, include_hide)
  local options = { "<Change Nothing>" }
  if include_hide then
    table.insert(options, "<Hide>")
  end
  for _, view in ipairs(view_list) do
    table.insert(options, view.label)
  end
  return options
end

-- Function to build options for visibility toggles
local function build_visibility_options()
  return { "<Change Nothing>", "<Hide>", "<Show>" }
end

-- Function to build options for detach toggles
local function build_detach_options()
  return { "<Change Nothing>", "Detached", "Attached" }
end

-- Function to build options for instrument box size
local function build_instrument_box_size_options()
  return { "<Change Nothing>", "Small", "Medium", "Large" }
end

function apply_dynamic_view_step(dv, step)
  local app_window = renoise.app().window
  local dv_id = string.format("%02d", dv)

  -- Safely get the values for upper, middle, and lower frame indices
  local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value or 1
  local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value or 1
  local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value or 1

  -- Apply Upper Frame
  if upper_frame_index == 1 then
    -- "<Change Nothing>" - do not change visibility or active frame
  elseif upper_frame_index >= 3 then
    -- Set the active frame and make sure it's visible
    app_window.active_upper_frame = views_upper[upper_frame_index - 2].frame
    app_window.upper_frame_is_visible = true
  elseif upper_frame_index == 2 then
    -- Hide the upper frame
    app_window.upper_frame_is_visible = false  -- "<Hide>"
  end
  
  -- Apply Middle Frame
  if middle_frame_index == 1 then
    -- "<Change Nothing>" - do nothing
  else
    local middle_frame = views_middle[middle_frame_index - 1].frame
    app_window.active_middle_frame = middle_frame

    -- Automatically hide the lower frame if a restricted middle frame is selected
    if is_restricted_middle_frame(middle_frame) then
      app_window.lower_frame_is_visible = false
      lower_frame_index = 2  -- Set to "<Hide>" for consistency
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value = 2
    end

    -- Uncheck the Pattern Advanced Edit and Pattern Matrix options if necessary
    if disable_pattern_matrix_and_advanced_edit(middle_frame) then
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value = 2  -- "<Hide>"
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = 2  -- "<Hide>"
    elseif middle_frame == disable_advanced_edit_mixer_frame then
      -- Only hide the Pattern Advanced Edit, allow Pattern Matrix
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = 2  -- "<Hide>"
    end
  end

  -- Apply Lower Frame
  if lower_frame_index == 1 then
    -- "<Change Nothing>" - do not change visibility or active frame
  elseif lower_frame_index == 2 then
    app_window.lower_frame_is_visible = false  -- "<Hide>"
  else
    app_window.active_lower_frame = views_lower[lower_frame_index - 2].frame
    app_window.lower_frame_is_visible = true
  end

  -- Apply Visibility Toggles
  local visibility_controls = {
    { property = "instrument_box_visible_step", apply = function(value)
        if value == 2 then
          app_window.instrument_box_is_visible = false
        elseif value == 3 then
          app_window.instrument_box_is_visible = true
        end
      end
    },
    { property = "instrument_box_slot_size_step", apply = function(value)
        if value == 2 then
          app_window.instrument_box_slot_size = 1  -- Small
        elseif value == 3 then
          app_window.instrument_box_slot_size = 2  -- Medium  
        elseif value == 4 then
          app_window.instrument_box_slot_size = 3  -- Large
        end
      end
    },
    { property = "disk_browser_visible_step", apply = function(value)
        if value == 2 then
          app_window.disk_browser_is_visible = false
        elseif value == 3 then
          app_window.disk_browser_is_visible = true
        end
      end
    },
    { property = "sample_record_visible_step", apply = function(value)
        if value == 2 then
          app_window.sample_record_dialog_is_visible = false
        elseif value == 3 then
          app_window.sample_record_dialog_is_visible = true
        end
      end
    },
    { property = "pattern_matrix_visible_step", apply = function(value)
        if value == 2 then
          app_window.pattern_matrix_is_visible = false
        elseif value == 3 then
          app_window.pattern_matrix_is_visible = true
        end
      end
    },
    { property = "pattern_advanced_edit_visible_step", apply = function(value)
        if value == 2 then
          app_window.pattern_advanced_edit_is_visible = false
        elseif value == 3 then
          app_window.pattern_advanced_edit_is_visible = true
        end
      end
    },
    { property = "instrument_editor_detached_step", apply = function(value)
        local success = pcall(function()
          if value == 2 then
            renoise.app().window.instrument_editor_is_detached = true   -- Detached
          elseif value == 3 then
            renoise.app().window.instrument_editor_is_detached = false  -- Attached
          end
        end)
      end
    },
    { property = "mixer_view_detached_step", apply = function(value)
        local success = pcall(function()
          if value == 2 then
            renoise.app().window.mixer_view_is_detached = true   -- Detached
          elseif value == 3 then
            renoise.app().window.mixer_view_is_detached = false  -- Attached
          end
        end)
      end
    }
  }

  for _, control in ipairs(visibility_controls) do
    local control_value = DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. control.property .. step].value or 1
    if control_value ~= 1 then  -- "<Change Nothing>" is 1
      control.apply(control_value)
    end
  end
end

function cycle_dynamic_view(dv)
  local dv_id = string.format("%02d", dv)
  local steps_count = 0
  local max_steps = steps_per_view
  local configured_steps = {}

  -- Reset current_steps for all other dynamic views
  for i = 1, dynamic_views_count do
    if i ~= dv then
      current_steps[i] = 0 -- Reset to 0
    end
  end

  -- Determine the list of configured steps
  for step = 1, max_steps do
    local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
    local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value

    -- Check visibility controls
    local visibility_changed = false
    local visibility_controls = {
      "sample_record_visible_step",
      "disk_browser_visible_step",
      "instrument_box_visible_step",
      "instrument_box_slot_size_step",
      "pattern_matrix_visible_step",
      "pattern_advanced_edit_visible_step",
      "instrument_editor_detached_step",
      "mixer_view_detached_step"
    }
    for _, ctrl in ipairs(visibility_controls) do
      local value = DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. ctrl .. step].value
      if value > 1 then
        visibility_changed = true
        break
      end
    end

    if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 or visibility_changed then
      table.insert(configured_steps, step)
    end
  end

  steps_count = #configured_steps

  if steps_count > 0 then
    -- Cycle to the next step
    local current_time = os.clock()
    if current_time - last_cycled_time[dv] < 0.1 then
      -- Debounce to prevent rapid cycling
      return
    end
    last_cycled_time[dv] = current_time

    local current_step_index = 0
    for index, step in ipairs(configured_steps) do
      if step == current_steps[dv] then
        current_step_index = index
        break
      end
    end

    local next_step_index = current_step_index + 1
    if next_step_index > steps_count then
      next_step_index = 1
    end
    local step = configured_steps[next_step_index]

    apply_dynamic_view_step(dv, step)
    current_steps[dv] = step

    -- Optionally, show status message
    -- Get the middle frame label
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
    local middle_frame_label = ""
    if middle_frame_index > 1 then
      middle_frame_label = views_middle[middle_frame_index - 1].label
    else
      middle_frame_label = "<Change Nothing>"
    end
    local status_message = "Paketti Dynamic View " .. dv_id .. " - Cycled to Step " .. string.format("%02d", step) .. ": " .. middle_frame_label
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("Paketti Dynamic View " .. dv_id .. " - No configured steps to cycle.")
  end
end


-- Function to build a row for a specific property across all steps
local function build_property_row(vb, dv_id, property_name, label_text, items_builder, update_steps_label)
  local row = vb:row{}
  row:add_child(vb:text{text=label_text,width=110, font = "bold" })
  for step = 1, steps_per_view do
    row:add_child(vb:popup{
      items = items_builder(),
      bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. property_name .. step],
      width=125,
      notifier=function()
        apply_dynamic_view_step(tonumber(dv_id), step)
        update_steps_label()
        saveDynamicViewPreferences()
      end
    })
  end
  return row
end

-- Build dynamic view UI
local function build_dynamic_view_ui(vb, dv)
  local dv_id = string.format("%02d", dv)
  local title_label = vb:text{text="Paketti Dynamic View " .. dv_id .. " (00)", font = "bold", width=200}

  local function update_steps_label()
    local steps_count = 0
    for step = 1, steps_per_view do
      local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
      local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
      local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value

      -- Check visibility controls
      local visibility_changed = false
      local visibility_controls = {
        "sample_record_visible_step",
        "disk_browser_visible_step",
        "instrument_box_visible_step",
        "pattern_matrix_visible_step",
        "pattern_advanced_edit_visible_step",
        "instrument_editor_detached_step",
        "mixer_view_detached_step"
      }
      for _, ctrl in ipairs(visibility_controls) do
        local value = DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. ctrl .. step].value
        if value > 1 then
          visibility_changed = true
          break
        end
      end

      if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 or visibility_changed then
        steps_count = steps_count + 1
      end
    end
    title_label.text = "Paketti Dynamic View " .. dv_id .. " (" .. string.format("%02d", steps_count) .. ")"
  end

  local function clear_visibility_controls()
    local visibility_controls = {
      "sample_record_visible_step",
      "disk_browser_visible_step",
      "instrument_box_visible_step",
      "instrument_box_slot_size_step",
      "pattern_matrix_visible_step",
      "pattern_advanced_edit_visible_step",
      "instrument_editor_detached_step",
      "mixer_view_detached_step"
    }
    for step = 1, steps_per_view do
      for _, ctrl in ipairs(visibility_controls) do
        DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. ctrl .. step].value = 1  -- "<Change Nothing>"
      end
    end
    update_steps_label()
    saveDynamicViewPreferences()
  end

  -- Initialize the label
  update_steps_label()

  local dv_column = vb:column{
  --  spacing=5,
    vb:row{
      title_label,
      vb:button{ text="Cycle", height = 20,width=60, pressed = function() cycle_dynamic_view(dv) end},
      vb:button{ text="Clear All Visibility Controls", height = 20,width=180, pressed = function() clear_visibility_controls() end}
    },
    build_property_row(vb, dv_id, "upper_step", "Upper Frame", function() return build_options(views_upper, true) end, update_steps_label),
    build_property_row(vb, dv_id, "middle_step", "Middle Frame", function() return build_options(views_middle, false) end, update_steps_label),
    build_property_row(vb, dv_id, "lower_step", "Lower Frame", function() return build_options(views_lower, true) end, update_steps_label),
    build_property_row(vb, dv_id, "instrument_box_visible_step", "Instrument Box", build_visibility_options, update_steps_label),
    build_property_row(vb, dv_id, "instrument_box_slot_size_step", "Instrument Size", build_instrument_box_size_options, update_steps_label),
    build_property_row(vb, dv_id, "disk_browser_visible_step", "Disk Browser", build_visibility_options, update_steps_label),
    build_property_row(vb, dv_id, "sample_record_visible_step", "Sample Recorder", build_visibility_options, update_steps_label),
    build_property_row(vb, dv_id, "pattern_matrix_visible_step", "Pattern Matrix", build_visibility_options, update_steps_label),
    build_property_row(vb, dv_id, "pattern_advanced_edit_visible_step", "Advanced Edit", build_visibility_options, update_steps_label),
    build_property_row(vb, dv_id, "instrument_editor_detached_step", "Instrument Editor", build_detach_options, update_steps_label),
    build_property_row(vb, dv_id, "mixer_view_detached_step", "Mixer View", build_detach_options, update_steps_label)
  }

  return dv_column
end

-- Assemble the dialog interface for dynamic views
function build_dialog_interface(vb, start_dv, end_dv, closeDV_dialog)
  local interface = vb:column{spacing=1 }
  for dv = start_dv, end_dv do
    interface:add_child(build_dynamic_view_ui(vb, dv))
  end
  
  interface:add_child(vb:row{
    vb:button{ text="Save Dynamic Views as a Textfile", height = 20,width=200, pressed = function() save_dynamic_views_to_txt() end},
    vb:button{ text="Load Dynamic Views from a Textfile", height = 20,width=200, pressed = function() load_dynamic_views_from_txt() end},
    vb:button{ text="Save & Close", height = 20,width=100, pressed = function()
      renoise.app():show_status("Saving current settings")
      saveDynamicViewPreferences()
      closeDV_dialog()
    end}
  })
  return interface
end

-- Dialog setup for dynamic views
function pakettiDynamicViewDialog(start_dv, end_dv)
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local dialog_content

  local function closeDV_dialog()
    if dialog and dialog.visible then
      dialog:close()
      dialog = nil
    end
  end

  dialog_content = build_dialog_interface(vb, start_dv, end_dv, closeDV_dialog)
  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Dynamic View Preferences Dialog " .. start_dv .. "-" .. end_dv, dialog_content, keyhandler, function()
    -- Save settings when the dialog is closed
    saveDynamicViewPreferences()
    dialog:close()
    dialog = nil  -- Clear reference when dialog closes
    renoise.app():show_status("Settings saved.")
  end)
end

-- Save Dynamic Views as .txt
function save_dynamic_views_to_txt()
  local file_path = renoise.app():prompt_for_filename_to_write("*.txt", "Save Dynamic Views as .txt")
  if not file_path then return end
  
  local file = io.open(file_path, "w")
  if not file then
    renoise.app():show_status("Error opening file for saving.")
    return
  end

  for dv = 1, dynamic_views_count do
    local dv_id = string.format("%02d", dv)
    file:write("Dynamic View " .. dv_id .. ":\n")
    for step = 1, steps_per_view do
      local upper = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
      local middle = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
      local lower = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value

      -- Map visibility control values to text
      local function visibility_value_to_text(value)
        if value == 1 then return "<Change Nothing>"
        elseif value == 2 then return "<Hide>"
        elseif value == 3 then return "<Show>"
        else return "<Unknown>"
        end
      end

      -- Map detach control values to text
      local function detach_value_to_text(value)
        if value == 1 then return "<Change Nothing>"
        elseif value == 2 then return "Detached"
        elseif value == 3 then return "Attached"
        else return "<Unknown>"
        end
      end

      -- Map instrument box size control values to text
      local function instrument_box_size_value_to_text(value)
        if value == 1 then return "<Change Nothing>"
        elseif value == 2 then return "Small"
        elseif value == 3 then return "Medium"
        elseif value == 4 then return "Large"
        else return "<Unknown>"
        end
      end

      local disk_browser = visibility_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value)
      local instrument_box = visibility_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value)
      local instrument_box_size = instrument_box_size_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_slot_size_step" .. step].value)
      local sample_recorder = visibility_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value)
      local pattern_matrix = visibility_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value)
      local advanced_edit = visibility_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value)
      local instrument_editor = detach_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_editor_detached_step" .. step].value)
      local mixer_view = detach_value_to_text(DynamicViewPrefs["dynamic_view" .. dv_id .. "_mixer_view_detached_step" .. step].value)

      file:write(string.format("  Step %d - Upper: %d, Middle: %d, Lower: %d, Disk Browser: %s, Instrument Box: %s, Instrument Box Size: %s, Sample Recorder: %s, Pattern Matrix: %s, Advanced Edit: %s, Instrument Editor: %s, Mixer View: %s\n",
        step, upper, middle, lower, disk_browser, instrument_box, instrument_box_size, sample_recorder, pattern_matrix, advanced_edit, instrument_editor, mixer_view))
    end
  end

  file:close()
  renoise.app():show_status("Dynamic Views saved successfully.")
end

-- Load Dynamic Views from .txt
function load_dynamic_views_from_txt()
  local file_path = renoise.app():prompt_for_filename_to_read({"*.txt"}, "Load Dynamic Views from .txt")
  if not file_path then return end
  
  local file = io.open(file_path, "r")
  if not file then
    renoise.app():show_status("Error opening file for loading.")
    return
  end

  local dv = nil
  for line in file:lines() do
    local dv_number = string.match(line, "^Dynamic View (%d+):")
    if dv_number then
      dv = tonumber(dv_number)
    else
      if dv then
        local dv_id = string.format("%02d", dv)
        local step, upper, middle, lower, disk_browser, instrument_box, instrument_box_size, sample_recorder, pattern_matrix, advanced_edit, instrument_editor, mixer_view = string.match(
          line,
          "Step (%d+) %- Upper: (%d+), Middle: (%d+), Lower: (%d+), Disk Browser: (%b<>), Instrument Box: (%b<>), Instrument Box Size: (%b<>), Sample Recorder: (%b<>), Pattern Matrix: (%b<>), Advanced Edit: (%b<>), Instrument Editor: (%b<>), Mixer View: (%b<>)"
        )
        if step then
          step = tonumber(step)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value = tonumber(upper)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value = tonumber(middle)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value = tonumber(lower)

          -- Map text to visibility control values
          local function text_to_visibility_value(text)
            if text == "<Change Nothing>" then return 1
            elseif text == "<Hide>" then return 2
            elseif text == "<Show>" then return 3
            else return 1  -- Default to "<Change Nothing>" if unknown
            end
          end

          -- Map text to detach control values
          local function text_to_detach_value(text)
            if text == "<Change Nothing>" then return 1
            elseif text == "Detached" then return 2
            elseif text == "Attached" then return 3
            else return 1  -- Default to "<Change Nothing>" if unknown
            end
          end

          -- Map text to instrument box size control values
          local function text_to_instrument_box_size_value(text)
            if text == "<Change Nothing>" then return 1
            elseif text == "Small" then return 2
            elseif text == "Medium" then return 3
            elseif text == "Large" then return 4
            else return 1  -- Default to "<Change Nothing>" if unknown
            end
          end

          DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value = text_to_visibility_value(disk_browser)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value = text_to_visibility_value(instrument_box)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_slot_size_step" .. step].value = text_to_instrument_box_size_value(instrument_box_size)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value = text_to_visibility_value(sample_recorder)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value = text_to_visibility_value(pattern_matrix)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = text_to_visibility_value(advanced_edit)
          
          -- Handle new detach properties if they exist in the loaded data
          if instrument_editor then
            DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_editor_detached_step" .. step].value = text_to_detach_value(instrument_editor)
          end
          if mixer_view then
            DynamicViewPrefs["dynamic_view" .. dv_id .. "_mixer_view_detached_step" .. step].value = text_to_detach_value(mixer_view)
          end
        end
      end
    end
  end

  file:close()
  saveDynamicViewPreferences()
  renoise.app():show_status("Dynamic Views loaded successfully.")
end

-- Updated function to set dynamic view step from MIDI knob value
function set_dynamic_view_step_from_knob(dv, knob_value)
  local dv_id = string.format("%02d", dv)
  local steps_count = 0
  local max_steps = steps_per_view
  local configured_steps = {}

  -- Determine the list of configured steps
  for step = 1, max_steps do
    local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
    local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value

    -- Check visibility controls
    local visibility_changed = false
    local visibility_controls = {
      "sample_record_visible_step",
      "disk_browser_visible_step",
      "instrument_box_visible_step",
      "instrument_box_slot_size_step",
      "pattern_matrix_visible_step",
      "pattern_advanced_edit_visible_step",
      "instrument_editor_detached_step",
      "mixer_view_detached_step"
    }
    for _, ctrl in ipairs(visibility_controls) do
      local value = DynamicViewPrefs["dynamic_view" .. dv_id .. "_" .. ctrl .. step].value
      if value > 1 then
        visibility_changed = true
        break
      end
    end

    if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 or visibility_changed then
      table.insert(configured_steps, step)
    end
  end

  steps_count = #configured_steps

  if steps_count > 0 then
    -- Map knob value to configured steps
    local index = math.floor((knob_value / 127) * (steps_count - 1) + 0.5) + 1
    if index < 1 then index = 1 end
    if index > steps_count then index = steps_count end
    local step = configured_steps[index]

    apply_dynamic_view_step(dv, step)
    current_steps[dv] = step

    -- Optionally, show status message
    -- Get the middle frame label
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
    local middle_frame_label = ""
    if middle_frame_index > 1 then
      middle_frame_label = views_middle[middle_frame_index - 1].label
    else
      middle_frame_label = "<Change Nothing>"
    end
    local status_message = "Paketti Dynamic View " .. dv_id .. " - Set to Step " .. string.format("%02d", step) .. ": " .. middle_frame_label
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("Paketti Dynamic View " .. dv_id .. " - No configured steps to select.")
  end
end

for dv = 1, dynamic_views_count do
  local dv_id = string.format("%02d", dv)
  renoise.tool():add_keybinding{name="Global:Paketti:Cycle Paketti Dynamic View " .. dv_id, invoke=function() cycle_dynamic_view(dv) end}
  renoise.tool():add_midi_mapping{name="Paketti:Cycle Paketti Dynamic View " .. dv_id, invoke=function() cycle_dynamic_view(dv) end}
  renoise.tool():add_midi_mapping{name="Paketti:Midi Paketti Dynamic View " .. dv_id .. " x[Knob]", 
    invoke=function(midi_message)
      if midi_message:is_abs_value() then
        local knob_value = midi_message.int_value
        set_dynamic_view_step_from_knob(dv, knob_value)
      end
    end}
  
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Dynamic View Preferences Dialog 1-4...", invoke=function() pakettiDynamicViewDialog(1, 4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Dynamic View Preferences Dialog 5-8...", invoke=function() pakettiDynamicViewDialog(5, 8) end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Dynamic View Preferences Dialog 1-4...", invoke=function() pakettiDynamicViewDialog(1, 4) end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Dynamic View Preferences Dialog 5-8...", invoke=function() pakettiDynamicViewDialog(5, 8) end}
