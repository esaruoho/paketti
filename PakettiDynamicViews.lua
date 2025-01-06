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

      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step, renoise.Document.ObservableBoolean(false))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step, renoise.Document.ObservableBoolean(false))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step, renoise.Document.ObservableBoolean(false))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step, renoise.Document.ObservableBoolean(false))
      DynamicViewPrefs:add_property("dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step, renoise.Document.ObservableBoolean(false))
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
        "instrument_box_visible_step", "pattern_matrix_visible_step",
        "pattern_advanced_edit_visible_step"
      }
      for _, prop_suffix in ipairs(prop_names) do
        local prop_name = "dynamic_view" .. dv_id .. "_" .. prop_suffix .. step
        if not DynamicViewPrefs:property(prop_name) then
          local default_value = prop_suffix:find("visible") and renoise.Document.ObservableBoolean(false) or renoise.Document.ObservableNumber(1)
          DynamicViewPrefs:add_property(prop_name, default_value)
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
  elseif upper_frame_index == 2 then
    app_window.upper_frame_is_visible = false  -- "<Hide>"
  else
    app_window.active_upper_frame = views_upper[upper_frame_index - 2].frame
    app_window.upper_frame_is_visible = true
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

    -- Uncheck the Pattern Advanced Edit checkbox if necessary
    if disable_pattern_matrix_and_advanced_edit(middle_frame) then
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value = false
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = false
    elseif middle_frame == disable_advanced_edit_mixer_frame then
      -- Only uncheck the Pattern Advanced Edit checkbox, allow Pattern Matrix
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = false
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
  app_window.sample_record_dialog_is_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value or false
  app_window.disk_browser_is_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value or false
  app_window.instrument_box_is_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value or false
  app_window.pattern_matrix_is_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value or false
  app_window.pattern_advanced_edit_is_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value or false
end


-- Function to cycle through each step in a Paketti Dynamic View with debounce
function cycle_dynamic_view(dv)
  local current_time = os.clock()
  local debounce_delay = 0.2 -- 200 milliseconds

  if (current_time - last_cycled_time[dv]) < debounce_delay then
    -- Not enough time has passed since the last cycle, ignore the call
    return
  end

  last_cycled_time[dv] = current_time

  local app_window = renoise.app().window
  local dv_id = string.format("%02d", dv)

  -- Reset current steps of other dynamic views
  for i = 1, dynamic_views_count do
    if i ~= dv then
      current_steps[i] = 0
    end
  end

  local steps_count = 0
  local max_steps = steps_per_view
  local configured_steps = {}

  -- Determine the list of configured steps
  for step = 1, max_steps do
    local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
    local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value
    if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 then
      table.insert(configured_steps, step)
    end
  end

  steps_count = #configured_steps

  if steps_count > 0 then
    -- Check if current view matches any step in the dynamic view
    local current_view_matches = false
    for _, step in ipairs(configured_steps) do
      local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
      local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
      local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value

      -- Extract checkbox states for the step
      local sample_recorder_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value
      local disk_browser_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value
      local instrument_box_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value
      local pattern_matrix_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value
      local pattern_advanced_edit_visible = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value

      -- Get current application window states
      local app_sample_recorder_visible = app_window.sample_record_dialog_is_visible
      local app_disk_browser_visible = app_window.disk_browser_is_visible
      local app_instrument_box_visible = app_window.instrument_box_is_visible
      local app_pattern_matrix_visible = app_window.pattern_matrix_is_visible
      local app_pattern_advanced_edit_visible = app_window.pattern_advanced_edit_is_visible

      -- Compare frames
      local matches_upper = (upper_frame_index == 1) or
        (upper_frame_index == 2 and not app_window.upper_frame_is_visible) or
        (upper_frame_index > 2 and app_window.upper_frame_is_visible and
         app_window.active_upper_frame == views_upper[upper_frame_index - 2].frame)

      local matches_middle = (middle_frame_index == 1) or
        (middle_frame_index > 1 and app_window.active_middle_frame == views_middle[middle_frame_index - 1].frame)

      local matches_lower = (lower_frame_index == 1) or
        (lower_frame_index == 2 and not app_window.lower_frame_is_visible) or
        (lower_frame_index > 2 and app_window.lower_frame_is_visible and
         app_window.active_lower_frame == views_lower[lower_frame_index - 2].frame)

      -- Compare checkbox states
      local matches_sample_recorder = (sample_recorder_visible == app_sample_recorder_visible)
      local matches_disk_browser = (disk_browser_visible == app_disk_browser_visible)
      local matches_instrument_box = (instrument_box_visible == app_instrument_box_visible)
      local matches_pattern_matrix = (pattern_matrix_visible == app_pattern_matrix_visible)
      local matches_pattern_advanced_edit = (pattern_advanced_edit_visible == app_pattern_advanced_edit_visible)

      if matches_upper and matches_middle and matches_lower and
         matches_sample_recorder and matches_disk_browser and
         matches_instrument_box and matches_pattern_matrix and
         matches_pattern_advanced_edit then
        current_steps[dv] = step
        current_view_matches = true
        break
      end
    end

    -- If current view does not match any step, reset to start from the beginning
    if not current_view_matches then
      current_steps[dv] = 0
    end

    -- Get the current step index in the configured_steps array
    local current_step_index = nil
    for i, step in ipairs(configured_steps) do
      if step == current_steps[dv] then
        current_step_index = i
        break
      end
    end

    -- If not in any step, start from the beginning
    if not current_step_index then
      current_step_index = 1
    else
      -- Move to next configured step
      current_step_index = (current_step_index % steps_count) + 1
    end

    local next_step = configured_steps[current_step_index]

    apply_dynamic_view_step(dv, next_step)
    current_steps[dv] = next_step

    -- Get the middle frame label
    local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. next_step].value
    local middle_frame_label = ""
    if middle_frame_index > 1 then
      middle_frame_label = views_middle[middle_frame_index - 1].label
    else
      middle_frame_label = "<Change Nothing>"
    end

    -- Format dynamic view and step numbers with leading zeros
    local step_str = string.format("%02d", next_step)

    local status_message = "Paketti Dynamic View " .. dv_id .. " - Showing Step " .. step_str .. ": " .. middle_frame_label
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("Paketti Dynamic View " .. dv_id .. " - No steps to cycle through.")
  end
end

-- Build the dialog content
local function build_step_column(vb, dv, step, update_steps_label)
  local dv_id = string.format("%02d", dv)
  return vb:column {
    vb:popup {
      items = build_options(views_upper, true),
      bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step],
      width = 150,
      notifier = function()
        apply_dynamic_view_step(dv, step)
        update_steps_label()
        saveDynamicViewPreferences()
      end
    },
    vb:popup {
      items = build_options(views_middle, false),
      bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step],
      width = 150,
      notifier = function()
        apply_dynamic_view_step(dv, step)
        update_steps_label()
        saveDynamicViewPreferences()
      end
    },
    vb:popup {
      items = build_options(views_lower, true),
      bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step],
      width = 150,
      notifier = function()
        apply_dynamic_view_step(dv, step)
        update_steps_label()
        saveDynamicViewPreferences()
      end
    },
    vb:row {
      vb:checkbox {
        bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step],
        notifier = function(value)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value = value
          if value then DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value = true end
          apply_dynamic_view_step(dv, step)
          update_steps_label()
          saveDynamicViewPreferences()
        end
      },
      vb:text { text = "Instrument Box Visible" }
    },
    vb:row {
      vb:checkbox {
        bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step],
        notifier = function()
          apply_dynamic_view_step(dv, step)
          update_steps_label()
          saveDynamicViewPreferences()
        end
      },
      vb:text { text = "Disk Browser Visible" }
    },
    vb:row {
      vb:checkbox {
        bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step],
        notifier = function()
          apply_dynamic_view_step(dv, step)
          update_steps_label()
          saveDynamicViewPreferences()
        end
      },
      vb:text { text = "Sample Recorder Visible" }
    },
    vb:row {
      vb:checkbox {
        bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step],
        notifier = function()
          apply_dynamic_view_step(dv, step)
          update_steps_label()
          saveDynamicViewPreferences()
        end
      },
      vb:text { text = "Pattern Matrix Visible" }
    },
    vb:row {
      vb:checkbox {
        bind = DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step],
        notifier = function()
          apply_dynamic_view_step(dv, step)
          update_steps_label()
          saveDynamicViewPreferences()
        end
      },
      vb:text { text = "Pattern Advanced Edit Visible" }
    }
  }
end

-- Build dynamic view UI
local function build_dynamic_view_ui(vb, dv)
  local dv_id = string.format("%02d", dv)
  local steps_label = vb:text { text = "Steps in Cycle: 0" }

  local function update_steps_label()
    local steps_count = 0
    for step = 1, steps_per_view do
      local upper_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value
      local middle_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value
      local lower_frame_index = DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value
      if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 then
        steps_count = steps_count + 1
      end
    end
    steps_label.text = "Steps in Cycle: " .. steps_count
  end

  local function clear_checkboxes()
    for step = 1, steps_per_view do
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value = false
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value = false
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value = false
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value = false
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = false
    end
    update_steps_label()
    saveDynamicViewPreferences()
  end

  -- Initialize the label
  update_steps_label()

  return vb:column {
    vb:row {
      vb:text { text = "Paketti Dynamic View " .. dv_id, font = "bold" },
      steps_label
    },
    vb:row { 
      build_step_column(vb, dv, 1, update_steps_label), 
      build_step_column(vb, dv, 2, update_steps_label), 
      build_step_column(vb, dv, 3, update_steps_label), 
      build_step_column(vb, dv, 4, update_steps_label),
      build_step_column(vb, dv, 5, update_steps_label), 
      build_step_column(vb, dv, 6, update_steps_label), 
      build_step_column(vb, dv, 7, update_steps_label), 
      build_step_column(vb, dv, 8, update_steps_label)
    },
    vb:row {
      vb:button { text = "Cycle", height = 10, width = 100, pressed = function() cycle_dynamic_view(dv) end },
      vb:button { text = "Clear All Checkboxes", height = 10, width = 160, pressed = function() clear_checkboxes() end }
    }
  }
end

-- Assemble the dialog interface for dynamic views
function build_dialog_interface(vb, start_dv, end_dv, close_dialog)
  local interface = vb:column {}
  for dv = start_dv, end_dv do
    interface:add_child(build_dynamic_view_ui(vb, dv))
    interface:add_child(vb:space { height = 5 })
  end
  -- Add Save, Save & Close, and Load buttons to the bottom
  interface:add_child(vb:row {
    vb:button { text = "Save Dynamic Views as a Textfile", height = 20, width = 150, pressed = function() save_dynamic_views_to_txt() end },
    vb:button { text = "Load Dynamic Views from a Textfile", height = 20, width = 150, pressed = function() load_dynamic_views_from_txt() end },
    vb:button { text = "Save & Close", height = 20, width = 100, pressed = function()
      renoise.app():show_status("Saving current settings")
      saveDynamicViewPreferences()
      close_dialog()
    end }
  })
  return interface
end

-- Dialog setup for dynamic views
function showDynamicViewDialog(start_dv, end_dv)
  local vb = renoise.ViewBuilder()
  local dialog_content
  local dialog

  local function close_dialog()
    if dialog and dialog.visible then
      dialog:close()
    end
  end

  dialog_content = build_dialog_interface(vb, start_dv, end_dv, close_dialog)
  dialog = renoise.app():show_custom_dialog("Paketti Dynamic View Preferences Dialog " .. start_dv .. "-" .. end_dv, dialog_content, function()
    -- Save settings when the dialog is closed
    saveDynamicViewPreferences()
    renoise.app():show_status("Settings saved.")
  end)
end

-- Save Dynamic Views as .txt
function save_dynamic_views_to_txt()
  local file_path = renoise.app():prompt_for_filename_to_write("txt", "Save Dynamic Views as .txt")
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
      local disk_browser = tostring(DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value)
      local instrument_box = tostring(DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value)
      local sample_recorder = tostring(DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value)
      local pattern_matrix = tostring(DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value)
      local advanced_edit = tostring(DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value)

      file:write(string.format("  Step %d - Upper: %d, Middle: %d, Lower: %d, Disk Browser: %s, Instrument Box: %s, Sample Recorder: %s, Pattern Matrix: %s, Pattern Advanced Edit: %s\n",
        step, upper, middle, lower, disk_browser, instrument_box, sample_recorder, pattern_matrix, advanced_edit))
    end
  end

  file:close()
  renoise.app():show_status("Dynamic Views saved successfully.")
end

-- Load Dynamic Views from .txt
function load_dynamic_views_from_txt()
  local file_path = renoise.app():prompt_for_filename_to_read({"txt"}, "Load Dynamic Views from .txt")
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
        local step, upper, middle, lower, disk_browser, instrument_box, sample_recorder, pattern_matrix, advanced_edit = string.match(
          line,
          "Step (%d+) %- Upper: (%d+), Middle: (%d+), Lower: (%d+), Disk Browser: (%w+), Instrument Box: (%w+), Sample Recorder: (%w+), Pattern Matrix: (%w+), Pattern Advanced Edit: (%w+)"
        )
        if step then
          step = tonumber(step)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_upper_step" .. step].value = tonumber(upper)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_middle_step" .. step].value = tonumber(middle)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_lower_step" .. step].value = tonumber(lower)
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value = (disk_browser == "true")
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value = (instrument_box == "true")
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value = (sample_recorder == "true")
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value = (pattern_matrix == "true")
          DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value = (advanced_edit == "true")
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

    -- Check checkboxes
    local has_checkbox_selected = 
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_sample_record_visible_step" .. step].value or
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_disk_browser_visible_step" .. step].value or
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_instrument_box_visible_step" .. step].value or
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_matrix_visible_step" .. step].value or
      DynamicViewPrefs["dynamic_view" .. dv_id .. "_pattern_advanced_edit_visible_step" .. step].value

    if upper_frame_index > 1 or middle_frame_index > 1 or lower_frame_index > 1 or has_checkbox_selected then
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




-- Add menu entries and keybindings for each dynamic view
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

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Dynamic View Preferences Dialog 1-4...", invoke=function() showDynamicViewDialog(1, 4) end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Dynamic View Preferences Dialog 5-8...", invoke=function() showDynamicViewDialog(5, 8) end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Dynamic View Preferences Dialog 1-4...", invoke=function() showDynamicViewDialog(1, 4) end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Dynamic View Preferences Dialog 5-8...", invoke=function() showDynamicViewDialog(5, 8) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti..:!Preferences..:Paketti Dynamic View Preferences Dialog 1-4...",invoke=function() showDynamicViewDialog(1, 4) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti Dynamic View Preferences Dialog 5-8...",invoke=function() showDynamicViewDialog(5, 8) end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti Save Dynamic Views as a Textfile", invoke=function() save_dynamic_views_to_txt() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:!Preferences..:Paketti Load Dynamic Views from a Textfile", invoke=function() load_dynamic_views_from_txt() end}
