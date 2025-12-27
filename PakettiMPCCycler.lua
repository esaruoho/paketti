-- PakettiMPCCycler.lua
-- MPC-style sample and instrument folder cycling
-- Comprehensive version with preferences, dialog, preview, MIDI mappings

-------------------------------------------------
-- Debug Configuration
-------------------------------------------------

local DEBUG = false

local function debug_print(...)
  if DEBUG then
    print("MPC Cycler:", ...)
  end
end

-------------------------------------------------
-- Extension definitions
-------------------------------------------------

local SAMPLE_EXTENSIONS = {"*.wav", "*.aif", "*.aiff", "*.flac", "*.ogg", "*.mp3"}
local INSTRUMENT_EXTENSIONS = {"*.xrni", "*.sfz", "*.sf2"}

-------------------------------------------------
-- ViewBuilder and Dialog
-------------------------------------------------

local vb = renoise.ViewBuilder()
local dialog = nil
local dialog_content = nil

-- UI element references for updates
local ui_sample_folder_text = nil
local ui_sample_file_text = nil
local ui_sample_position_text = nil
local ui_instrument_folder_text = nil
local ui_instrument_file_text = nil
local ui_instrument_position_text = nil
local ui_preview_checkbox = nil
local ui_global_lock_checkbox = nil

-------------------------------------------------
-- State management
-- Separate sample and instrument state
-------------------------------------------------

local sample_state = {
  folder = nil,
  index = 1,
  files = {}
}

local instrument_state = {
  folder = nil,
  index = 1,
  files = {}
}

-- Per-instrument state storage (when global lock is OFF)
local per_instrument_sample_state = {}
local per_instrument_instrument_state = {}

-- Preview state
local preview_instrument_index = nil
local preview_active = false
local original_instrument_index = nil

-------------------------------------------------
-- Preferences access
-------------------------------------------------

local function get_prefs()
  return renoise.tool().preferences
end

local function save_prefs()
  local prefs = get_prefs()
  -- Update preferences from current state
  if prefs.pakettiMPCCyclerLastSampleFolder then
    prefs.pakettiMPCCyclerLastSampleFolder.value = sample_state.folder or ""
  end
  if prefs.pakettiMPCCyclerLastInstrumentFolder then
    prefs.pakettiMPCCyclerLastInstrumentFolder.value = instrument_state.folder or ""
  end
  if prefs.pakettiMPCCyclerSampleIndex then
    prefs.pakettiMPCCyclerSampleIndex.value = sample_state.index or 1
  end
  if prefs.pakettiMPCCyclerInstrumentIndex then
    prefs.pakettiMPCCyclerInstrumentIndex.value = instrument_state.index or 1
  end
  debug_print("Preferences saved")
end

local function load_prefs()
  local prefs = get_prefs()
  if prefs.pakettiMPCCyclerLastSampleFolder then
    local folder = prefs.pakettiMPCCyclerLastSampleFolder.value
    if folder and folder ~= "" then
      sample_state.folder = folder
      debug_print("Loaded sample folder from prefs:", folder)
    end
  end
  if prefs.pakettiMPCCyclerLastInstrumentFolder then
    local folder = prefs.pakettiMPCCyclerLastInstrumentFolder.value
    if folder and folder ~= "" then
      instrument_state.folder = folder
      debug_print("Loaded instrument folder from prefs:", folder)
    end
  end
  if prefs.pakettiMPCCyclerSampleIndex then
    sample_state.index = prefs.pakettiMPCCyclerSampleIndex.value or 1
  end
  if prefs.pakettiMPCCyclerInstrumentIndex then
    instrument_state.index = prefs.pakettiMPCCyclerInstrumentIndex.value or 1
  end
end

local function is_global_lock()
  local prefs = get_prefs()
  if prefs.pakettiMPCCyclerGlobalLock then
    return prefs.pakettiMPCCyclerGlobalLock.value
  end
  return false
end

local function is_preview_enabled()
  local prefs = get_prefs()
  if prefs.pakettiMPCCyclerPreviewEnabled then
    return prefs.pakettiMPCCyclerPreviewEnabled.value
  end
  return false
end

-------------------------------------------------
-- State access (handles global lock vs per-instrument)
-------------------------------------------------

local function get_sample_state()
  if is_global_lock() then
    return sample_state
  end
  
  local song = renoise.song()
  if not song then return sample_state end
  
  local inst = song.selected_instrument
  if not inst then return sample_state end
  
  per_instrument_sample_state[inst] = per_instrument_sample_state[inst] or {
    folder = sample_state.folder,
    index = 1,
    files = {}
  }
  return per_instrument_sample_state[inst]
end

local function get_instrument_state()
  if is_global_lock() then
    return instrument_state
  end
  
  local song = renoise.song()
  if not song then return instrument_state end
  
  local inst = song.selected_instrument
  if not inst then return instrument_state end
  
  per_instrument_instrument_state[inst] = per_instrument_instrument_state[inst] or {
    folder = instrument_state.folder,
    index = 1,
    files = {}
  }
  return per_instrument_instrument_state[inst]
end

-------------------------------------------------
-- Path utilities
-------------------------------------------------

local function get_parent_folder(path)
  if not path then return nil end
  path = path:gsub("[/\\]$", "")
  local parent = path:match("^(.+)[/\\][^/\\]+$")
  return parent
end

local function join_path(a, b)
  if not a or not b then return nil end
  a = a:gsub("[/\\]$", "")
  return a .. "/" .. b
end

local function get_filename(path)
  if not path then return nil end
  return path:match("[^/\\]+$")
end

local function truncate_path(path, max_len)
  if not path then return "" end
  max_len = max_len or 40
  if #path <= max_len then return path end
  return "..." .. path:sub(-(max_len - 3))
end

-------------------------------------------------
-- File listing
-------------------------------------------------

local function get_files(folder, extensions)
  if not folder then return {} end
  
  local success, files = pcall(os.filenames, folder, extensions)
  if not success or not files then
    debug_print("Failed to list files in:", folder)
    return {}
  end
  
  table.sort(files)
  debug_print("Found", #files, "files in", folder)
  return files
end

local function get_folders(folder)
  if not folder then return {} end
  
  local success, dirs = pcall(os.dirnames, folder)
  if not success or not dirs then
    debug_print("Failed to list folders in:", folder)
    return {}
  end
  
  table.sort(dirs)
  debug_print("Found", #dirs, "folders in", folder)
  return dirs
end

-------------------------------------------------
-- UI Update
-------------------------------------------------

local function update_dialog_ui()
  if not dialog or not dialog.visible then return end
  
  local s_state = get_sample_state()
  local i_state = get_instrument_state()
  
  -- Update sample info
  if ui_sample_folder_text then
    ui_sample_folder_text.text = truncate_path(s_state.folder, 50) or "(not set)"
  end
  if ui_sample_file_text then
    local file = s_state.files[s_state.index]
    ui_sample_file_text.text = file or "(none)"
  end
  if ui_sample_position_text then
    local count = #s_state.files
    if count > 0 then
      ui_sample_position_text.text = string.format("%d / %d", s_state.index, count)
    else
      ui_sample_position_text.text = "0 / 0"
    end
  end
  
  -- Update instrument info
  if ui_instrument_folder_text then
    ui_instrument_folder_text.text = truncate_path(i_state.folder, 50) or "(not set)"
  end
  if ui_instrument_file_text then
    local file = i_state.files[i_state.index]
    ui_instrument_file_text.text = file or "(none)"
  end
  if ui_instrument_position_text then
    local count = #i_state.files
    if count > 0 then
      ui_instrument_position_text.text = string.format("%d / %d", i_state.index, count)
    else
      ui_instrument_position_text.text = "0 / 0"
    end
  end
  
  -- Update checkboxes
  if ui_preview_checkbox then
    ui_preview_checkbox.value = is_preview_enabled()
  end
  if ui_global_lock_checkbox then
    ui_global_lock_checkbox.value = is_global_lock()
  end
end

-------------------------------------------------
-- Loading functions
-------------------------------------------------

local function load_sample_file(file_path)
  local song = renoise.song()
  if not song then return false end
  
  local instrument = song.selected_instrument
  if not instrument then return false end
  
  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end
  
  local sample_index = song.selected_sample_index
  if sample_index < 1 or sample_index > #instrument.samples then
    sample_index = 1
  end
  
  local sample = instrument.samples[sample_index]
  if not sample then return false end
  
  local success = pcall(function()
    sample.sample_buffer:load_from(file_path)
  end)
  
  if success then
    local filename = get_filename(file_path)
    if filename then
      sample.name = filename:gsub("%.[^.]+$", "")
    end
    debug_print("Loaded sample:", file_path)
    return true
  end
  
  debug_print("Failed to load sample:", file_path)
  return false
end

local function load_instrument_file(file_path)
  local success = pcall(function()
    renoise.app():load_instrument(file_path)
  end)
  if success then
    debug_print("Loaded instrument:", file_path)
  else
    debug_print("Failed to load instrument:", file_path)
  end
  return success
end

-------------------------------------------------
-- Preview functions
-------------------------------------------------

local function create_preview_instrument()
  if preview_instrument_index then return preview_instrument_index end
  
  local song = renoise.song()
  if not song then return nil end
  
  -- Create at the end
  local new_index = #song.instruments + 1
  song:insert_instrument_at(new_index)
  song.instruments[new_index].name = "[MPC Preview]"
  
  preview_instrument_index = new_index
  debug_print("Created preview instrument at index:", new_index)
  return new_index
end

local function cleanup_preview_instrument()
  if not preview_instrument_index then return end
  
  local song = renoise.song()
  if not song then return end
  
  if preview_instrument_index <= #song.instruments then
    song:delete_instrument_at(preview_instrument_index)
    debug_print("Deleted preview instrument")
  end
  preview_instrument_index = nil
end

local function preview_sample(file_path)
  if not is_preview_enabled() then
    return load_sample_file(file_path)
  end
  
  local song = renoise.song()
  if not song then return false end
  
  -- Save original selection
  if not preview_active then
    original_instrument_index = song.selected_instrument_index
    preview_active = true
  end
  
  -- Create/get preview instrument
  local preview_idx = create_preview_instrument()
  if not preview_idx then return false end
  
  -- Select preview instrument and load
  song.selected_instrument_index = preview_idx
  local instrument = song.instruments[preview_idx]
  
  if #instrument.samples == 0 then
    instrument:insert_sample_at(1)
  end
  
  local sample = instrument.samples[1]
  local success = pcall(function()
    sample.sample_buffer:load_from(file_path)
  end)
  
  if success then
    local filename = get_filename(file_path)
    if filename then
      sample.name = filename:gsub("%.[^.]+$", "")
    end
    
    -- Trigger preview note
    local note_on = {
      instrument = preview_idx - 1,  -- 0-based
      note = 48,  -- C-4
      volume = 127
    }
    renoise.song().transport:trigger_instrument_note(preview_idx - 1, 0, 48, 127)
    
    debug_print("Previewing:", file_path)
    return true
  end
  
  return false
end

local function commit_preview()
  if not preview_active or not preview_instrument_index then
    renoise.app():show_status("MPC Cycler: No preview to commit")
    return
  end
  
  local song = renoise.song()
  if not song then return end
  
  -- Copy sample from preview to original instrument
  local preview_inst = song.instruments[preview_instrument_index]
  if not preview_inst or #preview_inst.samples == 0 then
    renoise.app():show_status("MPC Cycler: Preview has no sample")
    return
  end
  
  -- Go back to original instrument
  song.selected_instrument_index = original_instrument_index
  local target_inst = song.selected_instrument
  
  if #target_inst.samples == 0 then
    target_inst:insert_sample_at(1)
  end
  
  local target_sample = target_inst.samples[song.selected_sample_index]
  local preview_sample = preview_inst.samples[1]
  
  -- Copy sample data
  target_sample:copy_from(preview_sample)
  
  -- Cleanup
  cleanup_preview_instrument()
  preview_active = false
  original_instrument_index = nil
  
  renoise.app():show_status("MPC Cycler: Preview committed")
  debug_print("Preview committed")
end

local function cancel_preview()
  if not preview_active then return end
  
  local song = renoise.song()
  if song and original_instrument_index then
    song.selected_instrument_index = original_instrument_index
  end
  
  cleanup_preview_instrument()
  preview_active = false
  original_instrument_index = nil
  
  renoise.app():show_status("MPC Cycler: Preview cancelled")
  debug_print("Preview cancelled")
end

-------------------------------------------------
-- Set folder functions
-------------------------------------------------

local function mpc_set_sample_folder()
  local folder_path = renoise.app():prompt_for_path("MPC Cycler: Select Sample Folder")
  
  if folder_path and folder_path ~= "" then
    local state = get_sample_state()
    state.folder = folder_path
    state.index = 1
    state.files = get_files(folder_path, SAMPLE_EXTENSIONS)
    
    -- Also update global state for preferences
    sample_state.folder = folder_path
    save_prefs()
    
    update_dialog_ui()
    renoise.app():show_status("MPC Cycler: Sample folder set to " .. folder_path)
    debug_print("Sample folder set:", folder_path)
  end
end

local function mpc_set_instrument_folder()
  local folder_path = renoise.app():prompt_for_path("MPC Cycler: Select Instrument Folder")
  
  if folder_path and folder_path ~= "" then
    local state = get_instrument_state()
    state.folder = folder_path
    state.index = 1
    state.files = get_files(folder_path, INSTRUMENT_EXTENSIONS)
    
    -- Also update global state for preferences
    instrument_state.folder = folder_path
    save_prefs()
    
    update_dialog_ui()
    renoise.app():show_status("MPC Cycler: Instrument folder set to " .. folder_path)
    debug_print("Instrument folder set:", folder_path)
  end
end

-------------------------------------------------
-- Sample cycling
-------------------------------------------------

local function cycle_sample(direction)
  local state = get_sample_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No sample folder set. Use 'Set Sample Folder' first.")
    return
  end
  
  -- Refresh file list
  state.files = get_files(state.folder, SAMPLE_EXTENSIONS)
  if #state.files == 0 then
    renoise.app():show_status("MPC Cycler: No audio files in folder")
    return
  end
  
  -- Calculate new index with wraparound
  local new_index = state.index + direction
  if new_index < 1 then
    new_index = #state.files
  elseif new_index > #state.files then
    new_index = 1
  end
  
  state.index = new_index
  
  -- Update global state for preferences
  sample_state.index = new_index
  save_prefs()
  
  -- Build full path and load (or preview)
  local file_path = join_path(state.folder, state.files[new_index])
  local success
  
  if is_preview_enabled() then
    success = preview_sample(file_path)
  else
    success = load_sample_file(file_path)
  end
  
  update_dialog_ui()
  
  if success then
    renoise.app():show_status("MPC Cycler: " .. state.files[new_index] .. " (" .. new_index .. "/" .. #state.files .. ")")
  else
    renoise.app():show_status("MPC Cycler: Failed to load " .. state.files[new_index])
  end
end

local function mpc_previous_sample()
  cycle_sample(-1)
end

local function mpc_next_sample()
  cycle_sample(1)
end

-------------------------------------------------
-- Instrument cycling
-------------------------------------------------

local function cycle_instrument(direction)
  local state = get_instrument_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No instrument folder set. Use 'Set Instrument Folder' first.")
    return
  end
  
  -- Refresh file list
  state.files = get_files(state.folder, INSTRUMENT_EXTENSIONS)
  if #state.files == 0 then
    renoise.app():show_status("MPC Cycler: No instrument files in folder")
    return
  end
  
  -- Calculate new index with wraparound
  local new_index = state.index + direction
  if new_index < 1 then
    new_index = #state.files
  elseif new_index > #state.files then
    new_index = 1
  end
  
  state.index = new_index
  
  -- Update global state for preferences
  instrument_state.index = new_index
  save_prefs()
  
  -- Build full path and load
  local file_path = join_path(state.folder, state.files[new_index])
  local success = load_instrument_file(file_path)
  
  update_dialog_ui()
  
  if success then
    renoise.app():show_status("MPC Cycler: " .. state.files[new_index] .. " (" .. new_index .. "/" .. #state.files .. ")")
  else
    renoise.app():show_status("MPC Cycler: Failed to load " .. state.files[new_index])
  end
end

local function mpc_previous_instrument()
  cycle_instrument(-1)
end

local function mpc_next_instrument()
  cycle_instrument(1)
end

-------------------------------------------------
-- Folder navigation (Sample)
-------------------------------------------------

local function mpc_previous_sample_folder()
  local state = get_sample_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No sample folder set.")
    return
  end
  
  local parent = get_parent_folder(state.folder)
  if not parent then
    renoise.app():show_status("MPC Cycler: Cannot navigate - no parent folder")
    return
  end
  
  local folders = get_folders(parent)
  if #folders == 0 then
    renoise.app():show_status("MPC Cycler: No sibling folders found")
    return
  end
  
  local current_name = get_filename(state.folder)
  local current_index = 1
  for i, name in ipairs(folders) do
    if name == current_name then
      current_index = i
      break
    end
  end
  
  local new_index = current_index - 1
  if new_index < 1 then
    new_index = #folders
  end
  
  local new_folder = join_path(parent, folders[new_index])
  state.folder = new_folder
  state.index = 1
  state.files = get_files(new_folder, SAMPLE_EXTENSIONS)
  
  sample_state.folder = new_folder
  save_prefs()
  
  update_dialog_ui()
  renoise.app():show_status("MPC Cycler: Sample folder -> " .. folders[new_index])
end

local function mpc_next_sample_folder()
  local state = get_sample_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No sample folder set.")
    return
  end
  
  local parent = get_parent_folder(state.folder)
  if not parent then
    renoise.app():show_status("MPC Cycler: Cannot navigate - no parent folder")
    return
  end
  
  local folders = get_folders(parent)
  if #folders == 0 then
    renoise.app():show_status("MPC Cycler: No sibling folders found")
    return
  end
  
  local current_name = get_filename(state.folder)
  local current_index = 1
  for i, name in ipairs(folders) do
    if name == current_name then
      current_index = i
      break
    end
  end
  
  local new_index = current_index + 1
  if new_index > #folders then
    new_index = 1
  end
  
  local new_folder = join_path(parent, folders[new_index])
  state.folder = new_folder
  state.index = 1
  state.files = get_files(new_folder, SAMPLE_EXTENSIONS)
  
  sample_state.folder = new_folder
  save_prefs()
  
  update_dialog_ui()
  renoise.app():show_status("MPC Cycler: Sample folder -> " .. folders[new_index])
end

-------------------------------------------------
-- Folder navigation (Instrument)
-------------------------------------------------

local function mpc_previous_instrument_folder()
  local state = get_instrument_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No instrument folder set.")
    return
  end
  
  local parent = get_parent_folder(state.folder)
  if not parent then
    renoise.app():show_status("MPC Cycler: Cannot navigate - no parent folder")
    return
  end
  
  local folders = get_folders(parent)
  if #folders == 0 then
    renoise.app():show_status("MPC Cycler: No sibling folders found")
    return
  end
  
  local current_name = get_filename(state.folder)
  local current_index = 1
  for i, name in ipairs(folders) do
    if name == current_name then
      current_index = i
      break
    end
  end
  
  local new_index = current_index - 1
  if new_index < 1 then
    new_index = #folders
  end
  
  local new_folder = join_path(parent, folders[new_index])
  state.folder = new_folder
  state.index = 1
  state.files = get_files(new_folder, INSTRUMENT_EXTENSIONS)
  
  instrument_state.folder = new_folder
  save_prefs()
  
  update_dialog_ui()
  renoise.app():show_status("MPC Cycler: Instrument folder -> " .. folders[new_index])
end

local function mpc_next_instrument_folder()
  local state = get_instrument_state()
  
  if not state.folder then
    renoise.app():show_status("MPC Cycler: No instrument folder set.")
    return
  end
  
  local parent = get_parent_folder(state.folder)
  if not parent then
    renoise.app():show_status("MPC Cycler: Cannot navigate - no parent folder")
    return
  end
  
  local folders = get_folders(parent)
  if #folders == 0 then
    renoise.app():show_status("MPC Cycler: No sibling folders found")
    return
  end
  
  local current_name = get_filename(state.folder)
  local current_index = 1
  for i, name in ipairs(folders) do
    if name == current_name then
      current_index = i
      break
    end
  end
  
  local new_index = current_index + 1
  if new_index > #folders then
    new_index = 1
  end
  
  local new_folder = join_path(parent, folders[new_index])
  state.folder = new_folder
  state.index = 1
  state.files = get_files(new_folder, INSTRUMENT_EXTENSIONS)
  
  instrument_state.folder = new_folder
  save_prefs()
  
  update_dialog_ui()
  renoise.app():show_status("MPC Cycler: Instrument folder -> " .. folders[new_index])
end

-------------------------------------------------
-- Mode toggles
-------------------------------------------------

local function mpc_toggle_global_lock()
  local prefs = get_prefs()
  if prefs.pakettiMPCCyclerGlobalLock then
    prefs.pakettiMPCCyclerGlobalLock.value = not prefs.pakettiMPCCyclerGlobalLock.value
    local state = prefs.pakettiMPCCyclerGlobalLock.value and "ON" or "OFF"
    renoise.app():show_status("MPC Cycler: Global lock " .. state)
    update_dialog_ui()
  end
end

local function mpc_toggle_preview()
  local prefs = get_prefs()
  if prefs.pakettiMPCCyclerPreviewEnabled then
    prefs.pakettiMPCCyclerPreviewEnabled.value = not prefs.pakettiMPCCyclerPreviewEnabled.value
    local state = prefs.pakettiMPCCyclerPreviewEnabled.value and "ON" or "OFF"
    renoise.app():show_status("MPC Cycler: Preview mode " .. state)
    
    -- If disabling preview, cancel any active preview
    if not prefs.pakettiMPCCyclerPreviewEnabled.value then
      cancel_preview()
    end
    
    update_dialog_ui()
  end
end

local function mpc_commit_preview()
  commit_preview()
end

-------------------------------------------------
-- UserDefinedSampleFolders integration
-------------------------------------------------

local function jump_to_user_folder(folder_num)
  local prefs = get_prefs()
  local pref_key = "UserDefinedSampleFolders" .. string.format("%02d", folder_num)
  
  if prefs[pref_key] then
    local folder = prefs[pref_key].value
    if folder and folder ~= "" then
      local state = get_sample_state()
      state.folder = folder
      state.index = 1
      state.files = get_files(folder, SAMPLE_EXTENSIONS)
      
      sample_state.folder = folder
      save_prefs()
      
      update_dialog_ui()
      renoise.app():show_status("MPC Cycler: Jumped to folder " .. string.format("%02d", folder_num))
      debug_print("Jumped to user folder", folder_num, ":", folder)
    else
      renoise.app():show_status("MPC Cycler: Folder " .. string.format("%02d", folder_num) .. " not defined")
    end
  end
end

-------------------------------------------------
-- Dialog
-------------------------------------------------

local function create_dialog_content()
  vb = renoise.ViewBuilder()
  
  local s_state = get_sample_state()
  local i_state = get_instrument_state()
  
  ui_sample_folder_text = vb:text{
    text = truncate_path(s_state.folder, 50) or "(not set)",
    font = "mono",
    width = 350
  }
  
  ui_sample_file_text = vb:text{
    text = s_state.files[s_state.index] or "(none)",
    font = "bold",
    width = 350
  }
  
  ui_sample_position_text = vb:text{
    text = #s_state.files > 0 and string.format("%d / %d", s_state.index, #s_state.files) or "0 / 0",
    width = 80
  }
  
  ui_instrument_folder_text = vb:text{
    text = truncate_path(i_state.folder, 50) or "(not set)",
    font = "mono",
    width = 350
  }
  
  ui_instrument_file_text = vb:text{
    text = i_state.files[i_state.index] or "(none)",
    font = "bold",
    width = 350
  }
  
  ui_instrument_position_text = vb:text{
    text = #i_state.files > 0 and string.format("%d / %d", i_state.index, #i_state.files) or "0 / 0",
    width = 80
  }
  
  ui_preview_checkbox = vb:checkbox{
    value = is_preview_enabled(),
    notifier = function(value)
      local prefs = get_prefs()
      if prefs.pakettiMPCCyclerPreviewEnabled then
        prefs.pakettiMPCCyclerPreviewEnabled.value = value
        if not value then
          cancel_preview()
        end
      end
    end
  }
  
  ui_global_lock_checkbox = vb:checkbox{
    value = is_global_lock(),
    notifier = function(value)
      local prefs = get_prefs()
      if prefs.pakettiMPCCyclerGlobalLock then
        prefs.pakettiMPCCyclerGlobalLock.value = value
      end
      update_dialog_ui()
    end
  }
  
  return vb:column{
    margin = 10,
    spacing = 5,
    
    -- Title
    vb:text{
      text = "MPC Cycler",
      font = "big",
      style = "strong"
    },
    
    vb:space{height = 10},
    
    -- Sample Section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "SAMPLES", font = "bold"},
      vb:row{
        vb:text{text = "Folder:", width = 60},
        ui_sample_folder_text
      },
      vb:row{
        vb:text{text = "File:", width = 60},
        ui_sample_file_text
      },
      vb:row{
        vb:text{text = "Position:", width = 60},
        ui_sample_position_text,
        vb:button{text = "< Prev", width = 60, notifier = mpc_previous_sample},
        vb:button{text = "Next >", width = 60, notifier = mpc_next_sample},
        vb:button{text = "Set Folder", width = 80, notifier = mpc_set_sample_folder}
      },
      vb:row{
        vb:text{text = "Folders:", width = 60},
        vb:button{text = "< Prev Folder", width = 100, notifier = mpc_previous_sample_folder},
        vb:button{text = "Next Folder >", width = 100, notifier = mpc_next_sample_folder}
      }
    },
    
    vb:space{height = 5},
    
    -- Instrument Section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "INSTRUMENTS", font = "bold"},
      vb:row{
        vb:text{text = "Folder:", width = 60},
        ui_instrument_folder_text
      },
      vb:row{
        vb:text{text = "File:", width = 60},
        ui_instrument_file_text
      },
      vb:row{
        vb:text{text = "Position:", width = 60},
        ui_instrument_position_text,
        vb:button{text = "< Prev", width = 60, notifier = mpc_previous_instrument},
        vb:button{text = "Next >", width = 60, notifier = mpc_next_instrument},
        vb:button{text = "Set Folder", width = 80, notifier = mpc_set_instrument_folder}
      },
      vb:row{
        vb:text{text = "Folders:", width = 60},
        vb:button{text = "< Prev Folder", width = 100, notifier = mpc_previous_instrument_folder},
        vb:button{text = "Next Folder >", width = 100, notifier = mpc_next_instrument_folder}
      }
    },
    
    vb:space{height = 5},
    
    -- Options Section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "OPTIONS", font = "bold"},
      vb:row{
        ui_preview_checkbox,
        vb:text{text = "Preview Mode (audition before loading)"},
        vb:button{text = "Commit", width = 60, notifier = mpc_commit_preview}
      },
      vb:row{
        ui_global_lock_checkbox,
        vb:text{text = "Global Lock (share folders across all instruments)"}
      }
    },
    
    vb:space{height = 5},
    
    -- Quick Folders Section
    vb:column{
      style = "group",
      margin = 5,
      
      vb:text{text = "QUICK FOLDERS (UserDefinedSampleFolders)", font = "bold"},
      vb:row{
        vb:button{text = "01", width = 35, notifier = function() jump_to_user_folder(1) end},
        vb:button{text = "02", width = 35, notifier = function() jump_to_user_folder(2) end},
        vb:button{text = "03", width = 35, notifier = function() jump_to_user_folder(3) end},
        vb:button{text = "04", width = 35, notifier = function() jump_to_user_folder(4) end},
        vb:button{text = "05", width = 35, notifier = function() jump_to_user_folder(5) end},
        vb:button{text = "06", width = 35, notifier = function() jump_to_user_folder(6) end},
        vb:button{text = "07", width = 35, notifier = function() jump_to_user_folder(7) end},
        vb:button{text = "08", width = 35, notifier = function() jump_to_user_folder(8) end},
        vb:button{text = "09", width = 35, notifier = function() jump_to_user_folder(9) end},
        vb:button{text = "10", width = 35, notifier = function() jump_to_user_folder(10) end}
      }
    }
  }
end

local function show_mpc_cycler_dialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end
  
  dialog_content = create_dialog_content()
  
  dialog = renoise.app():show_custom_dialog(
    "MPC Cycler",
    dialog_content,
    my_keyhandler_func
  )
  
  -- Refresh focus
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

local function init()
  load_prefs()
  debug_print("MPC Cycler initialized")
end

-- Initialize on load
init()

-------------------------------------------------
-- Keybindings
-------------------------------------------------

-- Dialog
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Dialog", invoke=show_mpc_cycler_dialog}

-- Sample operations
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Set Sample Folder", invoke=mpc_set_sample_folder}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Previous Sample", invoke=mpc_previous_sample}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Next Sample", invoke=mpc_next_sample}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Previous Sample Folder", invoke=mpc_previous_sample_folder}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Next Sample Folder", invoke=mpc_next_sample_folder}

-- Instrument operations
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Set Instrument Folder", invoke=mpc_set_instrument_folder}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Previous Instrument", invoke=mpc_previous_instrument}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Next Instrument", invoke=mpc_next_instrument}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Previous Instrument Folder", invoke=mpc_previous_instrument_folder}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Next Instrument Folder", invoke=mpc_next_instrument_folder}

-- Mode toggles
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Toggle Preview Mode", invoke=mpc_toggle_preview}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Commit Preview", invoke=mpc_commit_preview}
renoise.tool():add_keybinding{name="Global:Paketti:MPC Cycler Toggle Global Lock", invoke=mpc_toggle_global_lock}

-- UserDefinedSampleFolders quick jump (01-10)
for i = 1, 10 do
  local folder_num = i
  renoise.tool():add_keybinding{
    name = "Global:Paketti:MPC Cycler Jump to Folder " .. string.format("%02d", i),
    invoke = function() jump_to_user_folder(folder_num) end
  }
end

-------------------------------------------------
-- MIDI Mappings
-------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Previous Sample [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_previous_sample()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Next Sample [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_next_sample()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Previous Instrument [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_previous_instrument()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Next Instrument [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_next_instrument()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Previous Sample Folder [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_previous_sample_folder()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Next Sample Folder [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_next_sample_folder()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Previous Instrument Folder [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_previous_instrument_folder()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Next Instrument Folder [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_next_instrument_folder()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Toggle Preview Mode [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_toggle_preview()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Commit Preview [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_commit_preview()
    end
  end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:MPC Cycler:Toggle Global Lock [Trigger]",
  invoke = function(msg)
    if msg:is_trigger() then
      mpc_toggle_global_lock()
    end
  end
}

-------------------------------------------------
-- Menu entries
-------------------------------------------------

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Show Dialog", invoke=show_mpc_cycler_dialog}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Set Sample Folder", invoke=mpc_set_sample_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Set Instrument Folder", invoke=mpc_set_instrument_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:---Sample Navigation---", invoke=function() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Previous Sample", invoke=mpc_previous_sample}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Next Sample", invoke=mpc_next_sample}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Previous Sample Folder", invoke=mpc_previous_sample_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Next Sample Folder", invoke=mpc_next_sample_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:---Instrument Navigation---", invoke=function() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Previous Instrument", invoke=mpc_previous_instrument}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Next Instrument", invoke=mpc_next_instrument}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Previous Instrument Folder", invoke=mpc_previous_instrument_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Next Instrument Folder", invoke=mpc_next_instrument_folder}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:---Mode Toggles---", invoke=function() end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Toggle Preview Mode", invoke=mpc_toggle_preview}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Commit Preview", invoke=mpc_commit_preview}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti..:MPC Cycler..:Toggle Global Lock", invoke=mpc_toggle_global_lock}


