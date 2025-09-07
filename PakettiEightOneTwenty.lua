-- Paketti Groovebox 8120 Script

-- Configuration: Maximum steps per row (16 or 32)
local MAX_STEPS = 16  -- Can be changed dynamically via UI switch
-- Globals used across features (declare early, avoid overengineering)
gbx_transpose_baseline = {nil,nil,nil,nil,nil,nil,nil,nil}
gbx_global_pitch_ui_prev_value = 0
gbx_global_pitch_midi_prev_abs = nil
--
-- NOTE: Step mode can be changed dynamically:
-- 1. Use the "16 Steps / 32 Steps" switch in the groovebox interface
-- 2. The UI will automatically recreate with the new step count
-- 3. All checkboxes, buttons, and step logic will adapt
-- 4. Pattern writing and fetching will work with the selected step count

-- Add this line right after stored_step_counts
local sequential_load_current_row = 1

-- BPM observable tracking
local bpm_observer = nil
local instruments_list_observer = nil
local beatsync_visible = false

-- BeatSync UI/observer state
local beatsync_checkboxes = {}
local beatsync_valueboxes = {}
local beatsync_updating = {}
local beatsync_enabled_observers = {}
local beatsync_lines_observers = {}
local beatsync_attached_inst_index = {}
local beatsync_attached_sample_index = {}
local beatsync_mode_observers = {}
local beatsync_mode_popups = {}
-- Advanced (BeatSync + NNA) columns for per-row highlighting
beatsync_adv_columns = {}
-- Baseline for absolute global pitch control (already initialized above)

-- Per-row recording state for Groovebox 8120
gbx_record_phase = {0,0,0,0,0,0,0,0} -- 0=idle, 1=armed (dialog visible), 2=recording
gbx_prev_sample_count = {0,0,0,0,0,0,0,0}
gbx_record_instrument_index = {0,0,0,0,0,0,0,0}

function PakettiEightOneTwentyRowRecordToggle(row_index)
  local song = renoise.song()
  if not song then return end
  local row_elements = rows and rows[row_index]
  if not row_elements then return end
  local track_popup = row_elements.track_popup
  local instrument_popup = row_elements.instrument_popup
  if not track_popup or not instrument_popup then return end

  local ti = track_indices and track_popup and track_popup.value and track_indices[track_popup.value]
  local ii = instrument_popup.value
  if ti then song.selected_track_index = ti end
  if ii then song.selected_instrument_index = ii end

  local phase = gbx_record_phase[row_index] or 0
  if phase == 0 then
    -- Arm: show recorder dialog and keep keyboard focus with Renoise
    renoise.app().window.sample_record_dialog_is_visible = true
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    gbx_record_phase[row_index] = 1
    renoise.app():show_status(string.format("8120 Row %02d: Recorder opened. Press Record to start.", row_index))
    return
  end

  if phase == 1 then
    -- Start recording
    local inst = song.instruments[ii]
    gbx_prev_sample_count[row_index] = (inst and #inst.samples or 0)
    gbx_record_instrument_index[row_index] = ii or 0
    song.transport:start_stop_sample_recording()
    gbx_record_phase[row_index] = 2
    renoise.app():show_status(string.format("8120 Row %02d: Recording... Press Record to stop.", row_index))
    return
  end

  if phase == 2 then
    -- Stop recording and finalize sample mapping
    song.transport:start_stop_sample_recording()

    local target_inst_index = gbx_record_instrument_index[row_index] or ii
    local inst = target_inst_index and song.instruments[target_inst_index] or nil
    if inst then
      local new_count = #inst.samples
      local prev_count = gbx_prev_sample_count[row_index] or 0
      local new_index = (new_count > 0) and new_count or 1
      if new_count == prev_count then
        -- Fallback: keep current selected sample index if no new slot detected
        new_index = song.selected_sample_index
      end

      if new_index < 1 then new_index = 1 end
      if new_index > #inst.samples then new_index = #inst.samples end

      song.selected_instrument_index = target_inst_index
      song.selected_sample_index = new_index

      -- Set velocity mapping: new sample 00-7F, others 00-00
      for si = 1, #inst.samples do
        local smp = inst.samples[si]
        if smp and smp.sample_mapping and not smp.sample_mapping.read_only then
          if si == new_index then
            smp.sample_mapping.velocity_range = {0x00, 0x7F}
          else
            smp.sample_mapping.velocity_range = {0x00, 0x00}
          end
        end
      end

      -- Enable convenience flags on the new sample
      if inst.samples[new_index] then
        inst.samples[new_index].autoseek = true
        inst.samples[new_index].autofade = true
      end
    end

    gbx_record_phase[row_index] = 0
    gbx_prev_sample_count[row_index] = 0
    gbx_record_instrument_index[row_index] = 0
    renoise.app():show_status(string.format("8120 Row %02d: Recording stopped. Sample selected and mapped.", row_index))
    return
  end
end

-- Helper to find the primary 00-7F sample for an instrument
function PakettiEightOneTwentyFindPrimarySampleIndex(instrument)
  if not instrument or not instrument.samples or #instrument.samples == 0 then
    return nil
  end
  for sample_idx, sample in ipairs(instrument.samples) do
    local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
    local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
    if velocity_min == 0x00 and velocity_max == 0x7F then
      return sample_idx
    end
  end
  return 1
end

function PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
  local inst_idx = beatsync_attached_inst_index[i]
  local smp_idx = beatsync_attached_sample_index[i]
  if inst_idx and smp_idx then
    local inst = renoise.song().instruments[inst_idx]
    if inst and inst.samples and inst.samples[smp_idx] then
      local smp = inst.samples[smp_idx]
      if beatsync_enabled_observers[i] and smp.beat_sync_enabled_observable:has_notifier(beatsync_enabled_observers[i]) then
        smp.beat_sync_enabled_observable:remove_notifier(beatsync_enabled_observers[i])
      end
      if beatsync_lines_observers[i] and smp.beat_sync_lines_observable:has_notifier(beatsync_lines_observers[i]) then
        smp.beat_sync_lines_observable:remove_notifier(beatsync_lines_observers[i])
      end
    end
  end
  beatsync_enabled_observers[i] = nil
  beatsync_lines_observers[i] = nil
  beatsync_attached_inst_index[i] = nil
  beatsync_attached_sample_index[i] = nil
end

function PakettiEightOneTwentyAttachBeatsyncObserversFor(i)
  local row_elements = rows[i]
  if not row_elements then return end
  local inst_idx = row_elements.instrument_popup and row_elements.instrument_popup.value
  local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
  if not inst then
    PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
    return
  end
  local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
  if not smp_idx then
    PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
    return
  end
  if beatsync_attached_inst_index[i] == inst_idx and beatsync_attached_sample_index[i] == smp_idx and beatsync_enabled_observers[i] and beatsync_lines_observers[i] then
    return
  end
  PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
  local smp = inst.samples[smp_idx]
  beatsync_enabled_observers[i] = function()
    local enabled = smp.beat_sync_enabled and true or false
    if beatsync_checkboxes[i] and beatsync_checkboxes[i].value ~= enabled then
      beatsync_updating[i] = true
      beatsync_checkboxes[i].value = enabled
      beatsync_updating[i] = false
    end
  end
  beatsync_lines_observers[i] = function()
    local lines = smp.beat_sync_lines or 0
    if beatsync_valueboxes[i] and beatsync_valueboxes[i].value ~= lines then
      beatsync_updating[i] = true
      beatsync_valueboxes[i].value = lines
      beatsync_updating[i] = false
    end
  end
  smp.beat_sync_enabled_observable:add_notifier(beatsync_enabled_observers[i])
  smp.beat_sync_lines_observable:add_notifier(beatsync_lines_observers[i])
  beatsync_attached_inst_index[i] = inst_idx
  beatsync_attached_sample_index[i] = smp_idx
  -- Prime UI
  beatsync_enabled_observers[i]()
  beatsync_lines_observers[i]()
end

function PakettiEightOneTwentyUpdateBeatsyncUiFor(i)
  local row_elements = rows[i]
  if not row_elements then return end
  local inst_idx = row_elements.instrument_popup and row_elements.instrument_popup.value
  local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
  if not inst or not inst.samples or #inst.samples == 0 then
    if beatsync_checkboxes[i] then beatsync_checkboxes[i].active = false end
    if beatsync_valueboxes[i] then beatsync_valueboxes[i].active = false end
    PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
    return
  end
  local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
  local smp = smp_idx and inst.samples[smp_idx] or nil
  if not smp then
    if beatsync_checkboxes[i] then beatsync_checkboxes[i].active = false end
    if beatsync_valueboxes[i] then beatsync_valueboxes[i].active = false end
    PakettiEightOneTwentyDetachBeatsyncObserversFor(i)
    return
  end
  if beatsync_checkboxes[i] then beatsync_checkboxes[i].active = true end
  if beatsync_valueboxes[i] then beatsync_valueboxes[i].active = true end
  beatsync_updating[i] = true
  if beatsync_checkboxes[i] then beatsync_checkboxes[i].value = smp.beat_sync_enabled and true or false end
  if beatsync_valueboxes[i] then beatsync_valueboxes[i].value = smp.beat_sync_lines or 0 end
  beatsync_updating[i] = false
  PakettiEightOneTwentyAttachBeatsyncObserversFor(i)
end

-- "Random" keybinding: Selects a random sample and mutes others
function sample_random()
  -- Initialize random seed for true randomness
  math.randomseed(os.time())
  
  local song=renoise.song()
  local ing = song.selected_instrument

  -- Edge case: no instrument or no samples
  if not ing or #ing.samples == 0 then
    renoise.app():show_status("No instrument or samples available.")
    return
  end

  -- Pick a random sample index
  local random_index = math.random(1, #ing.samples)
  song.selected_sample_index = random_index

  -- Set velocity ranges accordingly
  pakettiSampleVelocityRangeChoke(random_index)
end

-- Function to update track name with step count
local function updateTrackNameWithSteps(track, steps)
  local base_name = track.name:match("8120_%d+")
  if base_name then
    track.name = string.format("%s[%03d]", base_name, steps)
  end
end

-- Function to get step count from track name
local function getStepsFromTrackName(track_name)
  local steps = track_name:match("%[(%d+)%]")
  return steps and tonumber(steps) or MAX_STEPS -- Default to MAX_STEPS if no steps found
end


-- Initialization
local vb = renoise.ViewBuilder()
dialog = nil
rows = {}
local track_names, track_indices, instrument_names
track_names = {}  -- Initialize as empty table to avoid nil errors
track_indices = {}  -- Initialize as empty table to avoid nil errors
instrument_names = {}  -- Initialize as empty table to avoid nil errors
local play_checkbox, follow_checkbox, bpm_display, groove_enabled_checkbox, random_gate_button, fill_empty_label, fill_empty_slider, global_step_buttons, global_controls
local local_groove_sliders, local_groove_labels
local number_buttons_row
local number_buttons
local initializing = false  -- Add initializing flag

-- Ensure instruments exist
function ensure_instruments_exist()
  local instrument_count = #renoise.song().instruments
  if instrument_count < 8 then
    for i = instrument_count + 1, 8 do
      renoise.song():insert_instrument_at(i)
      renoise.song().instruments[i].name = ""  -- Set empty name instead of "Instrument " .. i
    end
  end
  instrument_names = {}
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "Instrument " .. i)
  end
end



-- Function to update instrument and track lists
function update_instrument_list_and_popups()
  instrument_names = {}
  for i, instr in ipairs(renoise.song().instruments) do
    table.insert(instrument_names, instr.name ~= "" and instr.name or "")  -- Use empty string as fallback
  end
  for i, row_elements in ipairs(rows) do
    local instrument_popup = row_elements.instrument_popup
    local previous_value = instrument_popup.value
    instrument_popup.items = instrument_names
    if previous_value <= #instrument_names then
      instrument_popup.value = previous_value
    else
      instrument_popup.value = 1
    end
    row_elements.update_sample_name_label()
  end

  track_names = {}
  track_indices = {}
  for i, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(track_names, track.name)
      table.insert(track_indices, i)
    end
  end
  for i, row_elements in ipairs(rows) do
    local track_popup = row_elements.track_popup
    local previous_value = track_popup.value
    track_popup.items = track_names
    if previous_value <= #track_names then
      track_popup.value = previous_value
    else
      track_popup.value = 1
    end
  end
end

-- Colors for step buttons (shared across all rows)
local normal_color, highlight_color = {0,0,0}, {0x22 / 255, 0xaa / 255, 0xff / 255}  -- EXACT copy from PakettiGater.lua
local selected_color = {0x80, 0x00, 0x80}  -- Purple for selected step (same as PakettiGater)
-- Resolve playhead color from preferences
function PakettiResolvePlayheadColor()
  local choice = (preferences and preferences.PakettiGrooveboxPlayheadColor and preferences.PakettiGrooveboxPlayheadColor.value) or 2
  if choice == 1 then return nil end -- None
  if choice == 2 then return {255,128,0} end -- Bright Orange
  if choice == 3 then return {64,0,96} end -- Deeper Purple (darker than selected purple)
  if choice == 4 then return {0,0,0} end -- Black
  if choice == 5 then return {255,255,255} end -- White
  if choice == 6 then return {64,64,64} end -- Dark Grey
  return {255,128,0}
end
play_color = PakettiResolvePlayheadColor()
play_color_is_deeper_purple = false
play_color_darker_variant = {40,0,72}

function PakettiEightOneTwentyApplyPlayheadColor()
  play_color = PakettiResolvePlayheadColor()
  play_color_is_deeper_purple = false
  if play_color and type(play_color) == "table" then
    if play_color[1] == 64 and play_color[2] == 0 and play_color[3] == 96 then
      play_color_is_deeper_purple = true
    end
  end
  PakettiEightOneTwentyUpdatePlayheadHighlights()
end

-- Playhead UI update state
playhead_timer_fn = nil
playing_observer_fn = nil

-- Update current-play-position highlight for all rows
function PakettiEightOneTwentyUpdatePlayheadHighlights()
  if not dialog or not dialog.visible then return end
  local song = renoise.song()
  if not song then return end
  local current_line = song.selected_line_index
  if song.transport.playing then
    local pos = song.transport.playback_pos
    if pos and pos.line then current_line = pos.line end
  end
  if current_line == nil then return end

  for i = 1, #rows do
    local row_elements = rows[i]
    if row_elements and row_elements.number_buttons then
      local steps = (row_elements.valuebox and row_elements.valuebox.value) or MAX_STEPS
      if not steps or steps < 1 then steps = 1 end

      local display_index

      -- Windowed cycling behavior:
      -- Advance only during the first MAX_STEPS lines of each "steps" window.
      -- Example: steps=32 in a 64-line pattern -> animate on 1..16, freeze on 17..32,
      -- restart on 33..48 (animate), freeze on 49..64, etc.
      local within_steps_window_index = ((current_line - 1) % steps) + 1
      if steps > MAX_STEPS then
        if within_steps_window_index <= MAX_STEPS then
          display_index = within_steps_window_index
        else
          -- During the frozen half of the window (e.g., 17..steps for steps=32)
          -- do not highlight any button
          display_index = nil
        end
      else
        display_index = ((within_steps_window_index - 1) % MAX_STEPS) + 1
      end
      if row_elements.play_step_index ~= display_index then
        row_elements.play_step_index = display_index
        update_row_button_colors(row_elements)
      end
    end
  end
end

-- Global Solo logic: allow multi-solo by muting non-solo rows
gbx_solo_active = false
gbx_prev_mute_states = {}

function PakettiEightOneTwentyApplySoloMutePolicy()
  local song = renoise.song()
  if not song or not rows then return end
  local any_solo = false
  for i = 1, math.min(8, #rows) do
    local re = rows[i]
    if re and re.solo_checkbox and re.solo_checkbox.value then
      any_solo = true
      break
    end
  end

  if any_solo then
    if not gbx_solo_active then
      -- Snapshot current mute states once when entering solo mode
      gbx_prev_mute_states = {}
      for i = 1, math.min(8, #song.tracks) do
        local trk = song:track(i)
        gbx_prev_mute_states[i] = (trk.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE)
      end
      gbx_solo_active = true
    end
    -- Apply solo: unmute soloed rows, mute others
    for i = 1, math.min(8, #song.tracks) do
      local trk = song:track(i)
      local re = rows[i]
      local is_solo = re and re.solo_checkbox and re.solo_checkbox.value
      local target_mute = not is_solo
      if target_mute then
        if trk.mute_state ~= renoise.Track.MUTE_STATE_MUTED then
          trk.mute_state = renoise.Track.MUTE_STATE_MUTED
        end
        if re and re.mute_checkbox and not re.mute_checkbox.value then
          re.updating_mute = true
          re.mute_checkbox.value = true
          re.updating_mute = false
        end
      else
        if trk.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
          trk.mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
        if re and re.mute_checkbox and re.mute_checkbox.value then
          re.updating_mute = true
          re.mute_checkbox.value = false
          re.updating_mute = false
        end
      end
    end
  else
    -- Exit solo mode: UNMUTE ALL tracks (do not restore previous mutes)
    if gbx_solo_active then
      for i = 1, math.min(8, #song.tracks) do
        local trk = song:track(i)
        if trk.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE then
          trk.mute_state = renoise.Track.MUTE_STATE_ACTIVE
        end
        local re = rows[i]
        if re and re.mute_checkbox and re.mute_checkbox.value then
          re.updating_mute = true
          re.mute_checkbox.value = false
          re.updating_mute = false
        end
      end
    end
    gbx_solo_active = false
    gbx_prev_mute_states = {}
  end
end

-- Setup timer and observers for playhead highlight updates
function PakettiEightOneTwentySetupPlayhead()
  local song = renoise.song()
  if not song then return end
  if not playhead_timer_fn then
    playhead_timer_fn = function()
      PakettiEightOneTwentyUpdatePlayheadHighlights()
    end
    renoise.tool():add_timer(playhead_timer_fn, 40)
  end
  if not playing_observer_fn then
    playing_observer_fn = function()
      play_color = PakettiResolvePlayheadColor()
      PakettiEightOneTwentyUpdatePlayheadHighlights()
    end
    if song.transport.playing_observable and not song.transport.playing_observable:has_notifier(playing_observer_fn) then
      song.transport.playing_observable:add_notifier(playing_observer_fn)
    end
  end
end

-- Cleanup timer and observers
function PakettiEightOneTwentyCleanupPlayhead()
  local song = renoise.song()
  if playhead_timer_fn then
    if renoise.tool():has_timer(playhead_timer_fn) then
      renoise.tool():remove_timer(playhead_timer_fn)
    end
    playhead_timer_fn = nil
  end
  if song and playing_observer_fn and song.transport.playing_observable and song.transport.playing_observable:has_notifier(playing_observer_fn) then
    song.transport.playing_observable:remove_notifier(playing_observer_fn)
  end
  playing_observer_fn = nil
  -- Clear play highlight state
  for i = 1, #rows do
    local re = rows[i]
    if re and re.play_step_index then
      re.play_step_index = nil
      update_row_button_colors(re)
    end
  end
end

-- Function to update button colors for a specific row
function update_row_button_colors(row_elements)
  if row_elements.number_buttons then
    for i = 1, #row_elements.number_buttons do
      local is_beat_marker = (i == 1 or i == 5 or i == 9 or i == 13 or i == 17 or i == 21 or i == 25 or i == 29)
      local is_selected = (i == row_elements.selected_step)
      local is_play_step = (row_elements.play_step_index ~= nil and i == row_elements.play_step_index)
      
      if is_play_step then
        local pc = play_color
        if is_selected and play_color_is_deeper_purple then
          pc = play_color_darker_variant
        end
        row_elements.number_buttons[i].color = pc
      elseif is_selected then
        row_elements.number_buttons[i].color = selected_color  -- Purple for selected
      elseif is_beat_marker then
        row_elements.number_buttons[i].color = highlight_color  -- Black for beat markers  
      else
        row_elements.number_buttons[i].color = normal_color  -- Default
      end
    end
  end
end

-- Get default automation value for groovebox8120 parameters
function PakettiEightOneTwentyGetDefaultValue(param_name, track_index)
  -- Special case: Pitchbend always gets 0.5 (center)
  if param_name == "Pitchbend" then
    print("8120 AUTOMATION DEBUG: Using default value 0.5 for Pitchbend")
    return 0.5
  end
  
  -- For other parameters, try to get macro knob value
  local song = renoise.song()
  local instrument = song.instruments[track_index]
  if not instrument or not instrument.macros then
    print("8120 AUTOMATION DEBUG: No instrument or macros found for track " .. track_index .. ", using parameter default")
    return 0.5  -- Fallback to center value
  end
  
  local macros = instrument.macros
  local macro_mapping = {
    ["Cutoff"] = 2,           -- Macro knob 02
    ["Resonance"] = 3,        -- Macro knob 03  
    ["CutLfoAmp"] = 4,        -- Macro knob 04
    ["CutLfoFreq"] = 5,       -- Macro knob 05
    ["Drive"] = 6,            -- Macro knob 06
    ["ParallelComp"] = 7      -- Macro knob 07
  }
  
  local macro_index = macro_mapping[param_name]
  if macro_index and macros[macro_index] then
    local macro_value = macros[macro_index].value
    print("8120 AUTOMATION DEBUG: Using macro value for " .. param_name .. " (macro " .. macro_index .. "): " .. macro_value)
    return macro_value
  end
  
  print("8120 AUTOMATION DEBUG: No macro mapping for " .. param_name .. ", using default 0.5")
  return 0.5  -- Default center value
end

-- Preserve automation selection (device + parameter) when switching tracks
function PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, new_track_index)
  print("8120 AUTOMATION DEBUG: *** FUNCTION CALLED *** with track " .. (new_track_index or "nil"))
  local app = renoise.app()
  print("8120 AUTOMATION DEBUG: Current lower frame: " .. (app.window.active_lower_frame or "nil"))
  print("8120 AUTOMATION DEBUG: AUTOMATION_FRAME constant: " .. renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION)
  
  if app.window.active_lower_frame ~= renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
    print("8120 AUTOMATION DEBUG: Not in automation view, skipping restoration")
    return
  end
  
  print("8120 AUTOMATION DEBUG: prev_device: " .. (prev_device and prev_device.name or "nil"))
  print("8120 AUTOMATION DEBUG: prev_param: " .. (prev_param and prev_param.name or "nil"))
  
  -- If no previous automation, force Pitchbend on *Instr. Macros device
  if not prev_device or not prev_param then 
    print("8120 AUTOMATION DEBUG: No previous device/parameter - FORCING Pitchbend on *Instr. Macros")
    local song = renoise.song()
    local new_track = song.tracks[new_track_index]
    if not new_track then 
      print("8120 AUTOMATION DEBUG: Target track doesn't exist")
      return 
    end
    
    -- Force selection of *Instr. Macros device and Pitchbend parameter
    prev_device = { name = "*Instr. Macros" }  -- Fake device for matching
    prev_param = { name = "Pitchbend" }        -- Force Pitchbend
    print("8120 AUTOMATION DEBUG: FORCED - prev_device: *Instr. Macros, prev_param: Pitchbend")
  end
  
  print("8120 AUTOMATION DEBUG: Trying to restore '" .. (prev_param.name or "unknown") .. "' from '" .. (prev_device.name or "unknown") .. "' to track " .. new_track_index)
  
  local song = renoise.song()
  local new_track = song.tracks[new_track_index]
  if not new_track then 
    print("8120 AUTOMATION DEBUG: New track doesn't exist")
    return 
  end
  
  -- List all devices on the new track for debugging
  print("8120 AUTOMATION DEBUG: *** SEARCHING DEVICES ON TRACK " .. new_track_index .. " ***")
  for di, device in ipairs(new_track.devices) do
    print("  [" .. di .. "] NAME: '" .. (device.name or "nil") .. "' DISPLAY: '" .. (device.display_name or "nil") .. "' PATH: '" .. (device.device_path or "nil") .. "' SHORT: '" .. (device.short_name or "nil") .. "'")
  end
  print("8120 AUTOMATION DEBUG: Total devices found: " .. #new_track.devices)
  
  -- For groovebox8120: PRIORITIZE *Instr. Macros device over exact parameter matching
  local target_device_index = nil
  local target_param = nil
  
  -- First, look for *Instr. Macros device (preferred for groovebox8120)
  local expected_display_name = string.format("%02X_Drumkit", new_track_index - 1)
  print("8120 AUTOMATION DEBUG: PRIORITIZING *Instr. Macros device - looking for name '*Instr. Macros' OR display_name '" .. expected_display_name .. "'")
  
  for i, device in ipairs(new_track.devices) do
    print("8120 AUTOMATION DEBUG: Checking device [" .. i .. "] name='" .. device.name .. "' display='" .. device.display_name .. "'")
    if device.name == "*Instr. Macros" or device.display_name == expected_display_name then
      target_device_index = i
      print("8120 AUTOMATION DEBUG: *** FOUND *Instr. Macros DEVICE *** at index " .. i .. ": " .. device.name .. " / " .. device.display_name)
      song.selected_device_index = target_device_index
      
      -- List all parameters on *Instr. Macros device for debugging  
      local device_obj = new_track.devices[target_device_index]
      print("8120 AUTOMATION DEBUG: Available parameters on *Instr. Macros device:")
      for pi, p in ipairs(device_obj.parameters) do
        if p.is_automatable then
          print("  [" .. pi .. "] '" .. (p.name or "unnamed") .. "' (automatable)")
        end
      end
      
      -- For groovebox8120: Prioritize specific parameters, NEVER X_PitchBend
      -- First try to find the same parameter (if it's NOT X_PitchBend)
      if prev_param.name ~= "X_PitchBend" then
        for _, p in ipairs(device_obj.parameters) do
          if p.name == prev_param.name and p.is_automatable then
            target_param = p
            print("8120 AUTOMATION DEBUG: Found matching parameter '" .. p.name .. "' on *Instr. Macros device")
            break
          end
        end
      end
      
      -- If no matching parameter or it was X_PitchBend, look for 'Pitchbend' ONLY
      if not target_param then
        for _, p in ipairs(device_obj.parameters) do
          if p.name == "Pitchbend" and p.is_automatable then
            target_param = p
            print("8120 AUTOMATION DEBUG: Using 'Pitchbend' parameter on *Instr. Macros: '" .. target_param.name .. "'")
            break
          end
        end
      end
      
      -- NO OTHER FALLBACKS - If no Pitchbend found, DO NOTHING
      if not target_param then
        print("8120 AUTOMATION DEBUG: No Pitchbend parameter found on *Instr. Macros device - DOING NOTHING")
        return
      end
      break
    end
  end
  
  -- If no *Instr. Macros device found, CREATE ONE instead of falling back to TrackVolPan
  if not target_device_index then
    print("8120 AUTOMATION DEBUG: No *Instr. Macros device found, CREATING ONE NOW")
    
    -- Save current selected track/instrument
    local orig_track = song.selected_track_index
    local orig_instrument = song.selected_instrument_index
    
    -- Switch to target track and instrument for groovebox8120 setup
    song.selected_track_index = new_track_index
    song.selected_instrument_index = new_track_index
    
    -- Add *Instr. Macros device
    loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
    local macro_device = new_track:device(#new_track.devices)
    macro_device.display_name = string.format("%02X_Drumkit", new_track_index - 1)
    macro_device.is_maximized = false
    
    print("8120 AUTOMATION DEBUG: Created *Instr. Macros device at index " .. #new_track.devices .. " with display name: " .. macro_device.display_name)
    
    -- Now set target to the newly created device
    target_device_index = #new_track.devices
    song.selected_device_index = target_device_index
    
    -- Look for Pitchbend parameter ONLY on the new device
    local device_obj = new_track.devices[target_device_index]
    for _, p in ipairs(device_obj.parameters) do
      if p.name == "Pitchbend" and p.is_automatable then
        target_param = p
        print("8120 AUTOMATION DEBUG: Using 'Pitchbend' parameter on newly created *Instr. Macros: '" .. target_param.name .. "'")
        break
      end
    end
    
    -- NO FALLBACKS - If no Pitchbend found on new device, DO NOTHING
    if not target_param then
      print("8120 AUTOMATION DEBUG: No Pitchbend parameter found on newly created *Instr. Macros device - DOING NOTHING")
      song.selected_track_index = orig_track
      song.selected_instrument_index = orig_instrument
      return
    end
    
    -- Restore original selection
    song.selected_track_index = orig_track
    song.selected_instrument_index = orig_instrument
  end
  
  -- If still no target found, exit
  if not target_device_index or not target_param then 
    print("8120 AUTOMATION DEBUG: No suitable device/parameter found, preserving current automation selection")
    return 
  end
  
  -- ALWAYS CREATE AUTOMATION ENVELOPE FIRST to prevent Renoise fallback to Volume
  local pattern = song.selected_pattern
  local pattern_track = pattern and pattern.tracks and pattern.tracks[new_track_index]
  if pattern_track then
    local existing = pattern_track:find_automation(target_param)
    if existing then
      if #existing.points == 0 then
        -- Envelope exists but is empty - add default points to prevent Renoise from falling back to other parameters
        local default_value = PakettiEightOneTwentyGetDefaultValue(target_param.name, new_track_index)
        existing:add_point_at(1, default_value)
        existing:add_point_at(pattern.number_of_lines, default_value)
        print("8120 AUTOMATION DEBUG: Added default points to empty " .. target_param.name .. " envelope (value: " .. default_value .. ")")
      else
        print("8120 AUTOMATION DEBUG: Envelope for " .. target_param.name .. " already has " .. #existing.points .. " points")
      end
    else
      -- CRITICAL: ALWAYS create envelope BEFORE setting parameter to prevent Volume fallback
      print("8120 AUTOMATION DEBUG: *** CREATING ENVELOPE FIRST *** for " .. target_param.name .. " to prevent Volume fallback")
      local automation = pattern_track:create_automation(target_param)
      if automation and pattern.number_of_lines and pattern.number_of_lines > 0 then
        local default_value = PakettiEightOneTwentyGetDefaultValue(target_param.name, new_track_index)
        automation:add_point_at(1, default_value)
        automation:add_point_at(pattern.number_of_lines, default_value)
        print("8120 AUTOMATION DEBUG: *** CREATED NEW ENVELOPE *** " .. target_param.name .. " with value " .. default_value .. " BEFORE setting parameter")
      else
        print("8120 AUTOMATION DEBUG: *** FAILED *** to create automation envelope for " .. target_param.name .. " - THIS WILL CAUSE VOLUME FALLBACK!")
        return  -- Don't set parameter if we can't create envelope
      end
    end
  else
    print("8120 AUTOMATION DEBUG: *** NO PATTERN TRACK *** - THIS WILL CAUSE VOLUME FALLBACK!")
    return
  end
  
  -- NOW set the automation parameter - envelope MUST exist to prevent Volume fallback
  print("8120 AUTOMATION DEBUG: *** SETTING AUTOMATION PARAMETER *** to '" .. target_param.name .. "' (envelope should exist)")
  
  -- Double-check envelope exists before setting parameter
  local final_check = pattern_track:find_automation(target_param)
  if final_check and #final_check.points > 0 then
    print("8120 AUTOMATION DEBUG: *** ENVELOPE VERIFIED *** " .. target_param.name .. " has " .. #final_check.points .. " points")
    song.selected_automation_parameter = target_param
    print("8120 AUTOMATION DEBUG: *** PARAMETER SET *** to '" .. target_param.name .. "' AFTER verifying envelope exists")
  else
    print("8120 AUTOMATION DEBUG: *** ENVELOPE MISSING *** for " .. target_param.name .. " - REFUSING TO SET PARAMETER TO PREVENT VOLUME FALLBACK")
    return
  end
  
  -- VERIFY what was actually selected
  local actually_selected_device = song.selected_automation_device
  local actually_selected_param = song.selected_automation_parameter
  print("8120 AUTOMATION DEBUG: *** VERIFICATION *** Actually selected device: " .. (actually_selected_device and actually_selected_device.name or "nil"))
  print("8120 AUTOMATION DEBUG: *** VERIFICATION *** Actually selected parameter: " .. (actually_selected_param and actually_selected_param.name or "nil"))
  
  local selected_device = new_track.devices[target_device_index]
  print("8120 AUTOMATION DEBUG: Restoration complete for " .. (selected_device.display_name or selected_device.name) .. " / " .. target_param.name)
  
  -- FINAL DEFINITIVE CONFIRMATION - what's actually selected
  local final_device = song.selected_automation_device
  local final_param = song.selected_automation_parameter
  print("8120 AUTOMATION DEBUG: *** FINAL RESULT *** SELECTED: " .. (final_device and final_device.name or "NO_DEVICE") .. " / " .. (final_param and final_param.name or "NO_PARAMETER"))
  print("8120 AUTOMATION DEBUG: *** END OF FUNCTION *** Device: " .. (final_device and final_device.name or "nil") .. " Parameter: " .. (final_param and final_param.name or "nil"))
end

-- Highlight handling for 8x120 rows
function PakettiEightOneTwentyHighlightRow(row_index)
  if initializing then return end
  if not rows then return end
  for i, row_elements in ipairs(rows) do
    local rc = row_elements and row_elements.row_container
    if rc then
      -- Available row styles: plain | border | group | panel | body
      if i == row_index then
        rc.style = "group" -- SELECTED: subtle outline
      else
        rc.style = "body"   -- NOT-SELECTED: light background
      end
    end
      -- Mirror highlight to advanced beatsync/NNA columns
      if beatsync_adv_columns and beatsync_adv_columns[i] then
        if i == row_index then
          beatsync_adv_columns[i].style = "group"
        else
          beatsync_adv_columns[i].style = "body"
        end
      end
  end
end

-- Function to create a row in the UI
function PakettiEightSlotsByOneTwentyCreateRow(row_index)
  local row_elements = {}
  
  -- Create Instrument Popup first
  local instrument_popup = vb:popup{
    items = instrument_names,
    value = row_index,  -- Set default instrument index to row number
    width=150,
    notifier=function(value)
      row_elements.print_to_pattern()
      row_elements.update_sample_name_label()
      -- Ensure transpose observer reattaches to the newly selected instrument
      if row_elements.attach_transpose_observer then
        row_elements.attach_transpose_observer()
      end
      -- Ensure volume observer reattaches to the newly selected instrument
      if row_elements.attach_volume_observer then
        row_elements.attach_volume_observer()
      end
      -- Keep BeatSync UI in sync for this row
      if beatsync_visible then
        PakettiEightOneTwentyUpdateBeatsyncUiFor(row_index)
      end
    end
  }
  
  -- Store instrument_popup in row_elements immediately
  row_elements.instrument_popup = instrument_popup

  -- Create Number Buttons (1-MAX_STEPS)
  local number_buttons = {}
  for i = 1, MAX_STEPS do
    number_buttons[i] = vb:button{
      text = string.format("%02d", i),
      width=30,
      color = normal_color,  -- Will be updated by update_row_button_colors()
      notifier=(function(step)
        return function()
          if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
          -- Update track name and valuebox
          local track_index = track_indices[row_elements.track_popup.value]
          local track = renoise.song():track(track_index)
          -- If automation is visible, capture current selection and switch track to this row
          local prev_device, prev_param = nil, nil
          if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
            prev_device = renoise.song().selected_automation_device
            prev_param = renoise.song().selected_automation_parameter
          end
          if track_index then
            renoise.song().selected_track_index = track_index
            renoise.song().selected_instrument_index = row_elements.instrument_popup.value
          end
          updateTrackNameWithSteps(track, step)
          row_elements.valuebox.value = step
          -- Update selected step
          if step == MAX_STEPS then
            row_elements.selected_step = nil
          else
            row_elements.selected_step = step
          end
          update_row_button_colors(row_elements)  -- Update button colors
          row_elements.print_to_pattern()
          print("8120 AUTOMATION DEBUG: *** AFTER print_to_pattern() *** Final automation: " .. (renoise.song().selected_automation_device and renoise.song().selected_automation_device.name or "nil") .. " / " .. (renoise.song().selected_automation_parameter and renoise.song().selected_automation_parameter.name or "nil"))
          renoise.app():show_status(string.format("Set steps to %d for row %d", step, row_index))
        end
      end)(i),
      active = true  -- Make buttons active
    }
  end
  
  -- Store number_buttons in row_elements for color updates
  row_elements.number_buttons = number_buttons
  


  -- Create number buttons row
  local number_buttons_plain = vb:row(number_buttons)

  -- Create transpose rotary with the available instrument_popup
  local instrument = renoise.song().instruments[instrument_popup.value]
  local current_transpose = instrument and instrument.transpose or 0
  local current_volume = instrument and instrument.volume or 1.0
  
  -- Clamp initial UI value for rotary to valid range
  local init_transpose_val = current_transpose
  if init_transpose_val < -64 then init_transpose_val = -64 end
  if init_transpose_val > 64 then init_transpose_val = 64 end

  local transpose_rotary = vb:rotary {
    min = -64,
    max = 64,
    value = init_transpose_val,
    width=25,
    height = 25,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      if row_elements and row_elements.updating_transpose then return end
      -- Get and select the track first
      local track_index = track_indices[row_elements.track_popup.value]
      local prev_device = nil
      local prev_param = nil
      if track_index then
        -- Capture current automation selection if automation frame is visible
        if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
          prev_device = renoise.song().selected_automation_device
          prev_param = renoise.song().selected_automation_parameter
        end
        renoise.song().selected_track_index = track_index
      end
      
      -- Update instrument transpose
      local instrument_index = instrument_popup.value
      local instrument = renoise.song().instruments[instrument_index]
      if instrument then
        instrument.transpose = value
      end
      
      -- Always select this row's instrument and its active sample
      renoise.song().selected_instrument_index = instrument_index
      -- Find and select the sample with 00-7F velocity mapping
      if instrument then
        for sample_idx, sample in ipairs(instrument.samples) do
          local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
          local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
          if velocity_min == 0x00 and velocity_max == 0x7F then
            renoise.song().selected_sample_index = sample_idx
            break
          end
        end
      end
      
      -- Try to restore automation selection on this track
      if track_index and prev_device and prev_param then
        PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, track_index)
      end
      --renoise.app():show_status(string.format("Set transpose to %+d for instrument %d: %s.", value, instrument_index, renoise.song().selected_sample.name))
    end
  }
    -- Create transpose label
    local transpose_label = vb:text{text="Pitch",font="bold",style="strong"}
    -- Create volume label and rotary
    local volume_label = vb:text{text="Vol",font="bold",style="strong"}
    local volume_rotary = vb:rotary{
      min = -1.0,
      max = 1.0,
      value = (current_volume or 1.0) - 1.0,
      width=25,
      height = 25,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
        if row_elements and row_elements.updating_volume then return end
        local now = os.clock()
        -- Select row's track and instrument before applying change
        local track_index = track_indices[row_elements.track_popup.value]
        if track_index then
          renoise.song().selected_track_index = track_index
        end
        local instrument_index = instrument_popup.value
        local inst = renoise.song().instruments[instrument_index]
        renoise.song().selected_instrument_index = instrument_index
        if inst then
          -- Map rotary -1..+1 to instrument volume 0..~1.99526 (0.0 -> 1.0)
          local mapped = (value + 1.0)
          if mapped < 0.0 then mapped = 0.0 end
          local max_volume = 1.99525
          if mapped > max_volume then mapped = max_volume end
          inst.volume = mapped
          -- Ensure the 00-7F velocity-mapped sample is selected for this instrument
          for sample_idx, sample in ipairs(inst.samples) do
            local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
            local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
            if velocity_min == 0x00 and velocity_max == 0x7F then
              renoise.song().selected_sample_index = sample_idx
              break
            end
          end
        end
        if row_elements then
          row_elements.last_volume_time = now
          row_elements.last_volume_value = value
        end
      end
    }
    
    -- Obsolete transpose_column not used in layout
    local transpose_column = nil
  
    -- Create the final number_buttons_row with transpose
    local number_buttons_row=vb:row{number_buttons_plain}
    
    -- Add Output Delay Controls
  local output_delay_label=vb:text{text="Output Delay",font="bold",style="strong"}
  local output_delay_value_label=vb:text{text="0ms",width=50,font="bold",style="strong"}

  local output_delay_slider = vb:slider{
    min= -100,
    max=100,
    steps={1,-1},
    value=renoise.song().tracks[row_index].output_delay,  -- Initialize with current value
    width=100,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then
        value = math.floor(value)  -- Ensure whole number
        renoise.song().tracks[track_index].output_delay = value
        output_delay_value_label.text = string.format("%+04dms", value)        
      end
    end
  }

  local output_delay_reset = vb:button{
    text="Reset",
    notifier=function()
      PakettiEightOneTwentyHighlightRow(row_index)
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then
        output_delay_slider.value = 0
        renoise.song().tracks[track_index].output_delay = 0
        output_delay_value_label.text="0ms"  -- Consistent format when reset
      end
    end
  }

  -- Add Output Delay Controls to the row
  number_buttons_row:add_child(output_delay_label)
  number_buttons_row:add_child(output_delay_slider)
  number_buttons_row:add_child(output_delay_value_label)
  number_buttons_row:add_child(output_delay_reset)

  -- Row-level loop controls (per-instrument)
  local function get_row_sample_for_full_velocity()
    local instrument_index = row_elements.instrument_popup and row_elements.instrument_popup.value
    local instrument = instrument_index and renoise.song().instruments[instrument_index]
    if not instrument or not instrument.samples then return nil end
    for sample_idx, sample in ipairs(instrument.samples) do
      local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
      local vmin = vr and vr[1]
      local vmax = vr and vr[2]
      if vmin == 0x00 and vmax == 0x7F then
        return sample
      end
    end
    return instrument.samples[1]
  end

  -- Removed per-row loop range label computation; only loop mode switch is used now

  local loop_sep = vb:text{text="|", font="bold", style="strong", width=8}
  local loop_label = vb:text{text="Loop", style="strong", font="bold"}
  -- Forward declaration so closures can reference it before assignment
  local update_row_loop_ui
  local loop_mode_switch = vb:switch{
    items = {"Off","->","<-","<->"},
    width = 140,
    value = 1,
    notifier = function(value)
      PakettiEightOneTwentyHighlightRow(row_index)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      -- Keep keyboard focus with Renoise
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
      if ti then renoise.song().selected_track_index = ti end
      local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
      if ii then renoise.song().selected_instrument_index = ii end
      -- Select the 00-7F sample if present
      do
        local inst = ii and renoise.song().instruments[ii] or nil
        if inst then
          for sample_idx, sample in ipairs(inst.samples) do
            local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
            local vmin = vr and vr[1]
            local vmax = vr and vr[2]
            if vmin == 0x00 and vmax == 0x7F then
              renoise.song().selected_sample_index = sample_idx
              break
            end
          end
        end
      end
      local sample = get_row_sample_for_full_velocity()
      if not sample then return end
      if value == 1 then
        sample.loop_mode = renoise.Sample.LOOP_MODE_OFF
      elseif value == 2 then
        sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
      elseif value == 3 then
        sample.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
      elseif value == 4 then
        sample.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
      end
      update_row_loop_ui()
    end
  }

  -- Loop Range Switch (Full / Start Half / End Half)
  local loop_range_switch = vb:switch{
    items = {"[--]","[- ]","[ -]"},
    width = 100,
    value = 1,
    notifier = function(val)
      PakettiEightOneTwentyHighlightRow(row_index)
      renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      -- Keep keyboard focus with Renoise
      renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
      -- Select this row's track and instrument/sample
      local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
      if ti then renoise.song().selected_track_index = ti end
      local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
      if ii then renoise.song().selected_instrument_index = ii end
      do
        local inst = ii and renoise.song().instruments[ii] or nil
        if inst then
          for sample_idx, sample in ipairs(inst.samples) do
            local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
            local vmin = vr and vr[1]
            local vmax = vr and vr[2]
            if vmin == 0x00 and vmax == 0x7F then
              renoise.song().selected_sample_index = sample_idx
              break
            end
          end
        end
      end
      local sample = get_row_sample_for_full_velocity()
      if not sample then return end
      local buf = sample.sample_buffer
      if not buf or not buf.has_sample_data then return end
      local n = buf.number_of_frames or 0
      if n <= 1 then return end
      local half = math.floor(n/2)
      if val == 1 then
        sample.loop_start = 1
        sample.loop_end = n
      elseif val == 2 then
        sample.loop_start = 1
        sample.loop_end = half
      elseif val == 3 then
        sample.loop_start = half
        sample.loop_end = n
      end
      update_row_loop_ui()
    end
  }

  update_row_loop_ui = function()
    local sample = get_row_sample_for_full_velocity()
    if not sample then
      loop_mode_switch.value = 1
      loop_mode_switch.active = false
      loop_range_switch.active = false
      return
    end
    loop_mode_switch.active = true
    loop_range_switch.active = true
    if sample.loop_mode == renoise.Sample.LOOP_MODE_OFF then
      loop_mode_switch.value = 1
    elseif sample.loop_mode == renoise.Sample.LOOP_MODE_FORWARD then
      loop_mode_switch.value = 2
    elseif sample.loop_mode == renoise.Sample.LOOP_MODE_REVERSE then
      loop_mode_switch.value = 3
    elseif sample.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG then
      loop_mode_switch.value = 4
    else
      loop_mode_switch.value = 2
    end
    -- Update range switch from current loop points
    local buf = sample.sample_buffer
    if buf and buf.has_sample_data then
      local n = buf.number_of_frames or 0
      if n > 0 then
        local half = math.floor(n/2)
        if sample.loop_start == 1 and sample.loop_end == n then
          loop_range_switch.value = 1
        elseif sample.loop_start == 1 and sample.loop_end == half then
          loop_range_switch.value = 2
        elseif sample.loop_start == half and sample.loop_end == n then
          loop_range_switch.value = 3
        else
          -- Leave as-is when custom
        end
      end
    end
  end

  -- Notifiers provided in constructors above

  -- initial sync
  update_row_loop_ui()
  -- Observe instrument changes; sample change observable not available globally in Song
  do
    local song = renoise.song()
    if song and song.selected_instrument_index_observable then
      song.selected_instrument_index_observable:add_notifier(function()
        update_row_loop_ui()
      end)
    end
  end

  -- Re-sync when instrument popup changes (extend existing notifier logic in constructor)
  -- Ensure the instrument_popup constructor calls update_row_loop_ui(); add it there if missing

  number_buttons_row:add_child(loop_sep)
  number_buttons_row:add_child(loop_label)
  number_buttons_row:add_child(loop_mode_switch)
  number_buttons_row:add_child(loop_range_switch)

  -- Store the row elements for later use
  row_elements.number_buttons_row = number_buttons_row
  row_elements.output_delay_slider = output_delay_slider
  row_elements.output_delay_value_label = output_delay_value_label

  -- Create Note Checkboxes (1-MAX_STEPS)
  local checkboxes = {}
  local checkbox_row_elements = {}
  for i = 1, MAX_STEPS do
    checkboxes[i] = vb:checkbox{
      value = false,
      width=30,
      notifier=function()
        local current_track = renoise.song().selected_track_index
        local target_track = track_indices[row_elements.track_popup.value]
        local current_track_name = renoise.song().tracks[current_track] and renoise.song().tracks[current_track].name or "Unknown"
        local target_track_name = target_track and renoise.song().tracks[target_track] and renoise.song().tracks[target_track].name or "Unknown"
        
        print("8120 AUTOMATION DEBUG: *** BUTTON CLICKED ROW " .. row_index .. " *** STARTING")
        print("8120 AUTOMATION DEBUG: Current track: " .. current_track .. " ('" .. current_track_name .. "') → Target track: " .. (target_track or "nil") .. " ('" .. target_track_name .. "')")
        
        -- CAPTURE automation selection at VERY START before ANYTHING happens
        local initial_device, initial_param = nil, nil
        if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
          initial_device = renoise.song().selected_automation_device
          initial_param = renoise.song().selected_automation_parameter
          print("8120 AUTOMATION DEBUG: *** INITIAL STATE *** Device: " .. (initial_device and initial_device.name or "nil") .. " Parameter: " .. (initial_param and initial_param.name or "nil"))
          if initial_param and initial_param.name == "Volume" then
            print("8120 AUTOMATION DEBUG: *** VOLUME ALREADY SELECTED *** Something else selected Volume before this button click!")
          end
        end
        

        
        
        if not row_elements.updating_checkboxes then
          -- Get and select the track first
          local track_index = track_indices[row_elements.track_popup.value]
          if track_index then
            local current_before = renoise.song().selected_track_index
            print("8120 AUTOMATION DEBUG: *** ABOUT TO SELECT TRACK " .. track_index .. " (from " .. current_before .. ") *** This will destroy automation selection!")
            
            if track_index == current_before then
              print("8120 AUTOMATION DEBUG: *** NO TRACK CHANGE NEEDED *** Already on target track " .. track_index)
              PakettiEightOneTwentyHighlightRow(row_index)
              return
            end
            
            -- CAPTURE automation BEFORE track selection destroys it
            local saved_device, saved_param = nil, nil
            if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
              saved_device = renoise.song().selected_automation_device
              saved_param = renoise.song().selected_automation_parameter
              print("8120 AUTOMATION DEBUG: *** SAVING AUTOMATION *** Device: " .. (saved_device and saved_device.name or "nil") .. " Parameter: " .. (saved_param and saved_param.name or "nil"))
            end
            
            renoise.song().selected_track_index = track_index
            local current_after = renoise.song().selected_track_index
            print("8120 AUTOMATION DEBUG: *** TRACK SELECTED *** " .. current_before .. " → " .. current_after .. " (requested " .. track_index .. ")")
            print("8120 AUTOMATION DEBUG: *** AFTER TRACK SWITCH *** Now automation is: " .. (renoise.song().selected_automation_device and renoise.song().selected_automation_device.name or "nil") .. " / " .. (renoise.song().selected_automation_parameter and renoise.song().selected_automation_parameter.name or "nil"))
            
            -- IMMEDIATELY restore automation to prevent Volume fallback
            if saved_device and saved_param and renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
              print("8120 AUTOMATION DEBUG: *** IMMEDIATELY RESTORING AUTOMATION *** to prevent Volume fallback")
              PakettiEightOneTwentyRestoreAutomationSelection(saved_device, saved_param, track_index)
            else
              print("8120 AUTOMATION DEBUG: *** NOT RESTORING *** saved_device:" .. (saved_device and saved_device.name or "nil") .. " saved_param:" .. (saved_param and saved_param.name or "nil"))
            end
            
            -- Now highlight the row after automation is restored
            PakettiEightOneTwentyHighlightRow(row_index)
          else
            print("8120 AUTOMATION DEBUG: *** NO TRACK INDEX *** track_indices[" .. row_elements.track_popup.value .. "] = nil")
            PakettiEightOneTwentyHighlightRow(row_index)
          end
          
          -- If we're in sample editor view, select the instrument and its active sample
          if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
            -- Select the instrument
            local instrument_index = row_elements.instrument_popup.value
            renoise.song().selected_instrument_index = instrument_index
            
            -- Find and select the sample with 00-7F velocity mapping
            local instrument = renoise.song().instruments[instrument_index]
            if instrument then
              for sample_idx, sample in ipairs(instrument.samples) do
                local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
                local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
                if velocity_min == 0x00 and velocity_max == 0x7F then
                  renoise.song().selected_sample_index = sample_idx
                  break
                end
              end
            end
          end
          
          -- Then print to pattern
          row_elements.print_to_pattern()
          if track_index and saved_device and saved_param then
            PakettiEightOneTwentyRestoreAutomationSelection(saved_device, saved_param, track_index)
          end
        end
      end
    }
    table.insert(checkbox_row_elements, checkboxes[i])
  end

  -- Valuebox for Steps
  local valuebox = vb:valuebox{
    min = 1,
    max = 512,
    value = MAX_STEPS,  -- Default to MAX_STEPS, will be updated in initialize_row()
    width=55,
    notifier=function(value)
      if initializing then return end
      PakettiEightOneTwentyHighlightRow(row_index)
      local prev_device, prev_param = nil, nil
      if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
        prev_device = renoise.song().selected_automation_device
        prev_param = renoise.song().selected_automation_parameter
      end
      if not row_elements.updating_steps then
        local track_index = track_indices[row_elements.track_popup.value]
        local track = renoise.song():track(track_index)
        -- Select the track first
        renoise.song().selected_track_index = track_index
        renoise.song().selected_instrument_index = row_elements.instrument_popup.value
        -- Then update track name and pattern
        updateTrackNameWithSteps(track, value)
        -- Update selected step
        if value == MAX_STEPS then
          row_elements.selected_step = nil
        else
          row_elements.selected_step = value
        end
        update_row_button_colors(row_elements)  -- Update button colors
        row_elements.print_to_pattern()
        if track_index and prev_device and prev_param then
          PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, track_index)
        end
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      --else 
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end
  }

  -- Sample Name Label
  local sample_name_label = vb:button{
    text="Sample Name",
    width = 400,
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      local track_index = track_indices[row_elements.track_popup.value]
      if track_index then renoise.song().selected_track_index = track_index end
      local instrument_index = row_elements.instrument_popup.value
      if instrument_index then renoise.song().selected_instrument_index = instrument_index end
      local inst = renoise.song().instruments[instrument_index]
      if inst then
        for sample_idx, sample in ipairs(inst.samples) do
          local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
          local vmin = vr and vr[1]
          local vmax = vr and vr[2]
          if vmin == 0x00 and vmax == 0x7F then
            renoise.song().selected_sample_index = sample_idx
            break
          end
        end
      end
      -- After selection, sync loop UI switches
      if update_row_loop_ui then update_row_loop_ui() end
    end
  }
  -- Try to left-align the sample name within the button by adding leading space removal when updating text
  row_elements.update_sample_name_label = function()
    local instrument_index = instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    local sample_name = ""
    if instrument and #instrument.samples > 0 then
      local selected_sample = instrument.samples[renoise.song().selected_sample_index] or instrument.samples[1]
      if selected_sample and selected_sample.name and selected_sample.name ~= "" then
        sample_name = selected_sample.name
      else
        sample_name = instrument.name ~= "" and instrument.name or ("Instrument " .. tostring(instrument_index))
      end
    else
      sample_name = instrument and (instrument.name ~= "" and instrument.name or ("Instrument " .. tostring(instrument_index))) or "Sample Name"
    end
    sample_name_label.text = sample_name
  end

  -- Append valuebox and sample name label after checkboxes
  table.insert(checkbox_row_elements, valuebox)
  table.insert(checkbox_row_elements, sample_name_label)

    -- Create Yxx Checkboxes (1-MAX_STEPS)
    local yxx_checkboxes = {}
    local yxx_checkbox_row_elements = {}
    for i = 1, MAX_STEPS do
      yxx_checkboxes[i] = vb:checkbox{
        value = false,
        width=30,
        notifier=function()
          if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
          if not row_elements.updating_yxx_checkboxes then
            local track_index = track_indices[row_elements.track_popup.value]
            if track_index then
              renoise.song().selected_track_index = track_index
            end
                      -- If we're in sample editor view, select the instrument and its active sample
          if renoise.app().window.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR then
            -- Select the instrument
            local instrument_index = row_elements.instrument_popup.value
            renoise.song().selected_instrument_index = instrument_index
            
            -- Find and select the sample with 00-7F velocity mapping
            local instrument = renoise.song().instruments[instrument_index]
            if instrument then
              for sample_idx, sample in ipairs(instrument.samples) do
                local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
                local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
                if velocity_min == 0x00 and velocity_max == 0x7F then
                  renoise.song().selected_sample_index = sample_idx
                  break
                end
              end
            end
          end

            row_elements.print_to_pattern()
            --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
          end
        end
      }
      table.insert(yxx_checkbox_row_elements, yxx_checkboxes[i])
    end
  
    -- Create the valuebox first
    local yxx_valuebox = vb:valuebox{
      min = 0,
      max = 255,
      value = 0,  -- Initialize to 00
    width=55,
      tostring = function(value)
        return string.format("%02X", value)
      end,
      tonumber = function(text)
        return tonumber(text, 16)
      end,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      row_elements.print_to_pattern()
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
    }  
  
    -- Create the slider that updates the valuebox
    local yxx_slider = vb:slider{
      min = 0,
      max = 255,
      steps = {1, -1},
      value = 32, -- Default to 0x20
      width=100,
      notifier=function(value)
        if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
        yxx_valuebox.value = math.floor(value)
        row_elements.print_to_pattern()
      end
    }
    row_elements.yxx_slider = yxx_slider
  
    -- Append yxx_valuebox and label after yxx checkboxes
    table.insert(yxx_checkbox_row_elements, yxx_valuebox)
    table.insert(yxx_checkbox_row_elements, vb:text{font="bold",style="strong",text="Yxx"})
  
  -- Randomize Button for Yxx Slider
  local yxx_randomize_button = vb:button{
    text="Random Yxx",
    width=70, -- Adjust width as needed
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      trueRandomSeed()
      local random_value = math.random(0, 255)
      yxx_slider.value = random_value
      yxx_valuebox.value = random_value
      row_elements.print_to_pattern()
    end
  }

  -- **Clear Button for Yxx Checkboxes**
  local yxx_clear_button = vb:button{
    text="Clear Yxx",
    width=40, -- Adjust width as needed
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      for _, checkbox in ipairs(yxx_checkboxes) do
        checkbox.value = false
      end
      row_elements.print_to_pattern()
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }

  -- Add slider and buttons to yxx_checkbox_row_elements
  table.insert(yxx_checkbox_row_elements, yxx_slider)
  table.insert(yxx_checkbox_row_elements, yxx_randomize_button)
  table.insert(yxx_checkbox_row_elements, yxx_clear_button)
  
  -- === End of Yxx Value Buttons Addition ===
  -- Adjusted Track Popup
  local default_track_index = row_index
  if default_track_index > #track_names then
    default_track_index = ((row_index - 1) % #track_names) + 1  -- Wrap around
  end

  local track_popup = vb:popup{
    items = track_names,
    value = default_track_index,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      row_elements.initialize_row()
      if row_elements.attach_mute_observer then
        row_elements.attach_mute_observer()
      end
      if row_elements.attach_solo_observer then
        row_elements.attach_solo_observer()
      end
      -- Clear any accidental selection caused by programmatic updates
      row_elements.selected_step = nil
      update_row_button_colors(row_elements)
    end
  }

  local mute_checkbox = vb:checkbox{
    value = false,
    width=30,
    notifier=function(value)
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
      local prev_device, prev_param = nil, nil
      if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
        prev_device = renoise.song().selected_automation_device
        prev_param = renoise.song().selected_automation_parameter
      end
      local track_index = track_indices[track_popup.value]
      local track = renoise.song().tracks[track_index]
      if row_elements and row_elements.updating_mute then return end
      if track then
        print("8120 MUTE UI → Track " .. tostring(track_index) .. " set to " .. (value and "MUTED" or "ACTIVE"))
        track.mute_state = value and renoise.Track.MUTE_STATE_MUTED or renoise.Track.MUTE_STATE_ACTIVE
        -- Also select this row's track and instrument, and focus the 00-7F sample
        if track_index then
          renoise.song().selected_track_index = track_index
        end
        local instrument_index = instrument_popup and instrument_popup.value
        if instrument_index then
          renoise.song().selected_instrument_index = instrument_index
          local inst = renoise.song().instruments[instrument_index]
          if inst and inst.samples and #inst.samples > 0 then
            for sample_idx, sample in ipairs(inst.samples) do
              local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
              local vmin = vr and vr[1]
              local vmax = vr and vr[2]
              if vmin == 0x00 and vmax == 0x7F then
                renoise.song().selected_sample_index = sample_idx
                break
              end
            end
          end
        end
      end
      if track_index and prev_device and prev_param then
        PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, track_index)
      end
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  }

  -- Setup two-way sync for track mute state
  row_elements.updating_mute = false
  row_elements.attached_track_index = nil
  row_elements.mute_observer_fn = nil

  function row_elements.detach_mute_observer()
    if row_elements.attached_track_index then
      local idx = row_elements.attached_track_index
      local trk = renoise.song().tracks[idx]
      if trk and row_elements.mute_observer_fn and trk.mute_state_observable:has_notifier(row_elements.mute_observer_fn) then
        trk.mute_state_observable:remove_notifier(row_elements.mute_observer_fn)
        -- Observer detached silently
      end
    end
    row_elements.attached_track_index = nil
    row_elements.mute_observer_fn = nil
  end

  function row_elements.attach_mute_observer()
    local idx = track_indices[track_popup.value]
    if not idx then return end
    if row_elements.attached_track_index == idx and row_elements.mute_observer_fn then
      return
    end
    row_elements.detach_mute_observer()
    local trk = renoise.song().tracks[idx]
    if not trk then return end
    row_elements.mute_observer_fn = function()
      local is_muted = (trk.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE)
      if mute_checkbox.value ~= is_muted then
        row_elements.updating_mute = true
        mute_checkbox.value = is_muted
        row_elements.updating_mute = false
        print("8120 MUTE TRACK → UI track " .. tostring(idx) .. " now " .. (is_muted and "checked" or "unchecked"))
      end
    end
    trk.mute_state_observable:add_notifier(row_elements.mute_observer_fn)
    row_elements.attached_track_index = idx
    -- Initialize UI from current state
    row_elements.mute_observer_fn()
    -- Observer attached silently
  end

  -- Solo observers attach/detach definitions
  row_elements.updating_solo = false
  row_elements.attached_track_index_solo = nil
  row_elements.solo_observer_fn = nil

  function row_elements.detach_solo_observer()
    if row_elements.attached_track_index_solo then
      local idx = row_elements.attached_track_index_solo
      local trk = renoise.song().tracks[idx]
      if trk and row_elements.solo_observer_fn and trk.solo_state_observable and trk.solo_state_observable:has_notifier(row_elements.solo_observer_fn) then
        trk.solo_state_observable:remove_notifier(row_elements.solo_observer_fn)
        -- Observer detached silently
      end
    end
    row_elements.attached_track_index_solo = nil
    row_elements.solo_observer_fn = nil
  end

  function row_elements.attach_solo_observer()
    local idx = track_indices[track_popup.value]
    if not idx then return end
    if row_elements.attached_track_index_solo == idx and row_elements.solo_observer_fn then
      return
    end
    row_elements.detach_solo_observer()
    local trk = renoise.song().tracks[idx]
    if not trk or not trk.solo_state_observable then return end
    row_elements.solo_observer_fn = function()
      local is_solo = (trk.solo_state and true or false)
      if row_elements.solo_checkbox and row_elements.solo_checkbox.value ~= is_solo then
        row_elements.updating_solo = true
        row_elements.solo_checkbox.value = is_solo
        row_elements.updating_solo = false
        print("8120 SOLO TRACK → UI track " .. tostring(idx) .. " now " .. (is_solo and "checked" or "unchecked"))
      end
    end
    trk.solo_state_observable:add_notifier(row_elements.solo_observer_fn)
    row_elements.attached_track_index_solo = idx
    -- Initialize UI from current state
    row_elements.solo_observer_fn()
    -- Observer attached silently
  end

  -- Function to map sample index to slider value
  function row_elements.sample_to_slider_value(sample_index, num_samples)
    if num_samples <= 0 then return 1 end
    -- Reverse the mapping: sample index -> slider value
    return math.floor(1 + ((sample_index - 1) * 120) / num_samples)
  end

  -- Function to map slider value to sample index
  function row_elements.slider_to_sample_index(slider_value, num_samples)
    if num_samples <= 0 then return 1 end
    -- Map slider value -> sample index
    local actual_value = math.floor(1 + ((slider_value - 1) / 120) * num_samples)
    return math.max(1, math.min(actual_value, num_samples))
  end

  local slider = vb:slider{
    min = 1,
    max = 120,
    value = 1,
    width=150,
    steps = {1, -1},
    notifier=function(value)
      value = math.floor(value)
      local instrument_index = row_elements.instrument_popup.value
      local instrument = renoise.song().instruments[instrument_index]
      if instrument and instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0 then
        renoise.app():show_status("This instrument contains Slices, doing nothing.")
        return
      end
      renoise.song().selected_instrument_index = instrument_index
      -- Set the selected track before changing the sample, preserving automation selection
      local track_index = track_indices[row_elements.track_popup.value]
      local prev_device = nil
      local prev_param = nil
      if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
        prev_device = renoise.song().selected_automation_device
        prev_param = renoise.song().selected_automation_parameter
      end
      renoise.song().selected_track_index = track_index
      if instrument and #instrument.samples > 0 then
        value = math.min(value, #instrument.samples)
        pakettiSampleVelocityRangeChoke(value)
        -- Switch to Sample Editor when the sample slider is moved
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
        -- Switched to Sample Editor silently
      end

      row_elements.update_sample_name_label()
      -- Try to restore automation selection on this track after changing sample focus
      if track_index and prev_device and prev_param then
        PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, track_index)
      end
    end
  }

  -- Update the slider value when updating sample name label
  local original_update_sample_name_label = row_elements.update_sample_name_label
  row_elements.update_sample_name_label = function()
    original_update_sample_name_label()
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument and #instrument.samples > 0 then
      slider.value = renoise.song().selected_sample_index
    end
  end

  -- Two-way sync for instrument transpose → UI rotary
  row_elements.updating_transpose = false
  row_elements.attached_instrument_index = nil
  row_elements.transpose_observer_fn = nil

  function row_elements.detach_transpose_observer()
    if row_elements.attached_instrument_index then
      local idx = row_elements.attached_instrument_index
      local inst = renoise.song().instruments[idx]
      if inst and row_elements.transpose_observer_fn and inst.transpose_observable:has_notifier(row_elements.transpose_observer_fn) then
        inst.transpose_observable:remove_notifier(row_elements.transpose_observer_fn)
        -- Observer detached silently
      end
    end
    row_elements.attached_instrument_index = nil
    row_elements.transpose_observer_fn = nil
  end

  function row_elements.attach_transpose_observer()
    local idx = row_elements.instrument_popup.value
    if not idx then return end
    if row_elements.attached_instrument_index == idx and row_elements.transpose_observer_fn then
      return
    end
    row_elements.detach_transpose_observer()
    local inst = renoise.song().instruments[idx]
    if not inst then return end
    row_elements.transpose_observer_fn = function()
      local val = inst.transpose or 0
      if val < -64 then val = -64 end
      if val > 64 then val = 64 end
      if transpose_rotary.value ~= val then
        row_elements.updating_transpose = true
        transpose_rotary.value = val
        row_elements.updating_transpose = false
        print("8120 TRANSPOSE INST → UI instrument " .. tostring(idx) .. " now " .. tostring(val))
      end
    end
    inst.transpose_observable:add_notifier(row_elements.transpose_observer_fn)
    row_elements.attached_instrument_index = idx
    -- Initialize UI from current state
    row_elements.transpose_observer_fn()
    -- Observer attached silently
  end

  -- Two-way sync for instrument volume → UI rotary
  row_elements.updating_volume = false
  row_elements.attached_instrument_index_for_volume = nil
  row_elements.volume_observer_fn = nil

  function row_elements.detach_volume_observer()
    if row_elements.attached_instrument_index_for_volume then
      local idx = row_elements.attached_instrument_index_for_volume
      local inst = renoise.song().instruments[idx]
      if inst and row_elements.volume_observer_fn and inst.volume_observable and inst.volume_observable:has_notifier(row_elements.volume_observer_fn) then
        inst.volume_observable:remove_notifier(row_elements.volume_observer_fn)
        -- Observer detached silently
      end
    end
    row_elements.attached_instrument_index_for_volume = nil
    row_elements.volume_observer_fn = nil
  end

  function row_elements.attach_volume_observer()
    local idx = row_elements.instrument_popup.value
    if not idx then return end
    if row_elements.attached_instrument_index_for_volume == idx and row_elements.volume_observer_fn then
      return
    end
    row_elements.detach_volume_observer()
    local inst = renoise.song().instruments[idx]
    if not inst or not inst.volume_observable then return end
    row_elements.volume_observer_fn = function()
      local val = inst.volume or 1.0
      local ui_val = (val - 1.0)
      if volume_rotary and volume_rotary.value ~= ui_val then
        row_elements.updating_volume = true
        volume_rotary.value = ui_val
        row_elements.updating_volume = false
        print("8120 VOLUME INST → UI instrument " .. tostring(idx) .. " now " .. tostring(val))
      end
    end
    inst.volume_observable:add_notifier(row_elements.volume_observer_fn)
    row_elements.attached_instrument_index_for_volume = idx
    -- Initialize UI from current state
    row_elements.volume_observer_fn()
    -- Observer attached silently
  end

  -- instrument_popup already created earlier and stored into row_elements

-- Function to Print to Pattern
function row_elements.print_to_pattern()
  if initializing then return end
  local song=renoise.song()
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local steps = valuebox.value
  local track_index = track_indices[track_popup.value]
  local instrument_index = instrument_popup.value
  local track_in_pattern = pattern.tracks[track_index]

  -- Ensure the track has at least one visible effect column
  local track = renoise.song().tracks[track_index]
  if track.visible_effect_columns == 0 then
    track.visible_effect_columns = 1
  end

  -- First clear all lines in the pattern for this track
  for line = 1, pattern_length do
    local note_line = track_in_pattern:line(line).note_columns[1]
    local effect_column = track_in_pattern:line(line).effect_columns[1]
    note_line:clear()
    effect_column:clear()
  end

  -- Only write notes to the first MAX_STEPS steps
  for line = 1, math.min(MAX_STEPS, steps) do
    local note_checkbox_value = checkboxes[line].value
    local yxx_checkbox_value = yxx_checkboxes[line].value
    local note_line = track_in_pattern:line(line).note_columns[1]
    local effect_column = track_in_pattern:line(line).effect_columns[1]

    if note_checkbox_value then
      note_line.note_string = "C-4"
      note_line.instrument_value = instrument_index - 1

      if yxx_checkbox_value then
        effect_column.number_string = "0Y"
        effect_column.amount_value = yxx_valuebox.value
      else
        effect_column:clear()
      end
    end
  end

  -- Repeat the pattern if needed
  if pattern_length > steps then
    local full_repeats = math.floor(pattern_length / steps)
    for repeat_num = 1, full_repeats - 1 do
      local start_line = repeat_num * steps + 1
      for line = 1, math.min(MAX_STEPS, steps) do
        local source_line = track_in_pattern:line(line)
        local dest_line = track_in_pattern:line(start_line + line - 1)
        dest_line.note_columns[1]:copy_from(source_line.note_columns[1])
        dest_line.effect_columns[1]:copy_from(source_line.effect_columns[1])
      end
    end
  end
end

  -- Function to Update Sample Name Label
  function row_elements.update_sample_name_label()
    local instrument = renoise.song().instruments[instrument_popup.value]
    local sample_name = "No sample available"
    if instrument and #instrument.samples > 0 then
      for sample_idx, sample in ipairs(instrument.samples) do
        local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
        local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
        if velocity_min == 0x00 and velocity_max == 0x7F then
          sample_name = sample.name ~= "" and sample.name or string.format("Sample %d", sample_idx)
          -- Truncate sample name if longer than 50 characters
          if #sample_name > 50 then
            sample_name = sample_name:sub(1, 47) .. "..."
          end
          break
        end
      end
      -- Only show status if we have an instrument but couldn't find a valid sample
      if sample_name == "No sample available" then
        renoise.app():show_status(string.format("Instrument %d ('%s') has no samples with full velocity range (00-7F)", 
          instrument_popup.value, instrument.name))
      end
    end
    sample_name_label.text = sample_name
  end

  -- Function to Initialize Row
  function row_elements.initialize_row()
    local track_index = track_indices[track_popup.value]
    if track_index then
      local track = renoise.song().tracks[track_index]
      -- Get step count from track name when initializing row
      local step_count = getStepsFromTrackName(track.name)
      valuebox.value = step_count
      -- Do not set selected_step during initialization. Start with no highlight.
      row_elements.selected_step = nil
      update_row_button_colors(row_elements)  -- Update button colors

      local current_delay = renoise.song().tracks[track_index].output_delay
      output_delay_slider.value = current_delay
      output_delay_value_label.text = string.format("%+04dms", current_delay)
        end

    local track = renoise.song().tracks[track_index]
    local pattern = renoise.song().selected_pattern
    local line_count = pattern.number_of_lines
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true

    for i = 1, MAX_STEPS do
      checkboxes[i].active = false
      checkboxes[i].value = false
      yxx_checkboxes[i].active = false
      yxx_checkboxes[i].value = false
    end

    local yxx_value_found = false

    for line = 1, math.min(line_count, MAX_STEPS) do
      local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
      local effect_column = pattern.tracks[track_index].lines[line].effect_columns[1]
      if note_line and note_line.note_string == "C-4" then
        checkboxes[line].value = true
        if effect_column and effect_column.number_string == "0Y" then
          yxx_checkboxes[line].value = true
          yxx_valuebox.value = effect_column.amount_value
          yxx_value_found = true
        else
          yxx_checkboxes[line].value = false
        end
      end
    end

    if not yxx_value_found then
      yxx_valuebox.value = 0  -- Initialize to 00 if no Yxx content
    end

    local mute = (track.mute_state ~= renoise.Track.MUTE_STATE_ACTIVE)
    row_elements.updating_mute = true
    mute_checkbox.value = mute
    row_elements.updating_mute = false
    -- Initialize Solo checkbox
    local solo = (track.solo_state and true or false)
    if row_elements.solo_checkbox then
      row_elements.updating_solo = true
      row_elements.solo_checkbox.value = solo
      row_elements.updating_solo = false
    end

  -- Find the current 00-7F sample and set slider accordingly
  local instrument = renoise.song().instruments[instrument_popup.value]
  if instrument then
    -- Sync transpose knob to instrument on init (clamped to UI range)
    row_elements.updating_transpose = true
    local init_t = instrument.transpose or 0
    if init_t < -64 then init_t = -64 end
    if init_t > 64 then init_t = 64 end
    transpose_rotary.value = init_t
    row_elements.updating_transpose = false
    local found_samples = {}
    for sample_index, sample in ipairs(instrument.samples) do
      local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
      local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
      if velocity_min == 0x00 and velocity_max == 0x7F then
        table.insert(found_samples, sample_index)
      end
    end
    
    -- If exactly one 00-7F sample found, set slider to that index
    -- Otherwise, set to minimum value
    if #found_samples == 1 then
      slider.value = found_samples[1]
    else
      slider.value = 1
    end
  end

    local instrument_used = nil
    for line = 1, math.min(line_count, MAX_STEPS) do
      local note_line = pattern.tracks[track_index].lines[line].note_columns[1]
      if note_line and not note_line.is_empty and note_line.note_string ~= '---' then
        instrument_used = note_line.instrument_value
        break
      end
    end

    if instrument_used and instrument_used + 1 <= #instrument_names then
      instrument_popup.value = instrument_used + 1
    else
      instrument_popup.value = row_index  -- Set default instrument index to row number
    end

    -- Ensure transpose and volume observers are attached to current instrument
    if row_elements.attach_transpose_observer then
      row_elements.attach_transpose_observer()
    end
    if row_elements.attach_volume_observer then
      row_elements.attach_volume_observer()
    end

    row_elements.update_sample_name_label()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false

    for i = 1, MAX_STEPS do
      checkboxes[i].active = true
      yxx_checkboxes[i].active = true
    end
  end

  -- Function to Browse Instrument
  function row_elements.browse_instrument()
    local track_popup_value = track_popup.value
    local instrument_popup_value = instrument_popup.value
    local track_index = track_indices[track_popup_value]
    local instrument_index = instrument_popup_value
    renoise.song().selected_track_index = track_index
    renoise.song().selected_instrument_index = instrument_index

      pitchBendDrumkitLoader()

    local instrument = renoise.song().instruments[instrument_index]
    if not instrument then
      renoise.app():show_warning("Selected instrument does not exist.")
      return
    end

    for _, sample in ipairs(instrument.samples) do
      sample.sample_mapping.base_note = 48
      sample.sample_mapping.note_range = {0, 119}
    end

    renoise.app():show_status("Base notes set to C-4 and key mapping adjusted for all samples.")

    if renoise.song().tracks[track_index] then
      -- Preserve the 8120 track name format
      local track = renoise.song().tracks[track_index]
      if not track.name:match("^8120_%d+%[%d+%]$") then
        local base_name = string.format("8120_%02d", track_index)
        track.name = string.format("%s[%03d]", base_name, MAX_STEPS)  -- Initialize with MAX_STEPS
      end
    else
      renoise.app():show_warning("Selected track does not exist.")
    end

    update_instrument_list_and_popups()
    slider.value = 1

      pakettiSampleVelocityRangeChoke(1)

    update_instrument_list_and_popups()
    row_elements.random_button_pressed = row_elements.random_button_pressed
  end

  -- Function to Refresh Instruments
  function row_elements.refresh_instruments()
    update_instrument_list_and_popups()
  end

  -- Function to Select Instrument
  function row_elements.select_instrument()
    renoise.song().selected_instrument_index = instrument_popup.value
    local track_index = track_indices[track_popup.value]
    local track = renoise.song().tracks[track_index]
    renoise.song().selected_track_index = track_index


  end

  -- Function for Random Button Pressed
  function row_elements.random_button_pressed()
    if initializing then return end
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument and instrument.samples[1] and instrument.samples[1].slice_markers and #instrument.samples[1].slice_markers > 0 then
      renoise.app():show_status("This instrument contains Slices, doing nothing.")
      return
    end
    renoise.song().selected_instrument_index = instrument_index
    sample_random()

    -- Update slider to match the currently selected sample
    local selected_index = renoise.song().selected_sample_index
    if selected_index and selected_index > 0 then
      slider.value = selected_index
    end

    row_elements.update_sample_name_label()
    renoise.song().selected_track_index = 1
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end

  -- Function to Randomize Steps
  function row_elements.randomize()
    if initializing then return end
    trueRandomSeed()
    
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    for i = 1, MAX_STEPS do
      checkboxes[i].value = math.random() >= 0.5
      yxx_checkboxes[i].value = math.random() >= 0.5
    end
    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end

  function row_elements.show_automation()
    local current_track = renoise.song().selected_track_index
    local target_track = track_indices[track_popup.value]
    local current_track_name = renoise.song().tracks[current_track] and renoise.song().tracks[current_track].name or "Unknown"
    local target_track_name = target_track and renoise.song().tracks[target_track] and renoise.song().tracks[target_track].name or "Unknown"
    
    print("8120 AUTOMATION DEBUG: *** AUTOMATION BUTTON CLICKED ROW " .. row_index .. " ***")
    print("8120 AUTOMATION DEBUG: Current track: " .. current_track .. " ('" .. current_track_name .. "') → Target track: " .. (target_track or "nil") .. " ('" .. target_track_name .. "')")
    
    -- CAPTURE automation selection BEFORE track selection destroys it
    local saved_device, saved_param = nil, nil
    if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
      saved_device = renoise.song().selected_automation_device
      saved_param = renoise.song().selected_automation_parameter
      print("8120 AUTOMATION DEBUG: *** SAVING AUTOMATION *** Device: " .. (saved_device and saved_device.name or "nil") .. " Parameter: " .. (saved_param and saved_param.name or "nil"))
    end
    
    -- Highlight this row in the 8120 interface
    PakettiEightOneTwentyHighlightRow(row_index)
    
    local song=renoise.song()
    local track_index = track_indices[track_popup.value]
    local track = song.tracks[track_index]
    local instrument_index = instrument_popup.value
    
    if not track_index then
      print("8120 AUTOMATION DEBUG: *** ERROR *** No track index for row " .. row_index)
      return
    end
    
    -- Switch to automation view FIRST
    renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    renoise.app().window.lower_frame_is_visible = true
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    
    -- Select both the track and instrument for this row
    if track_index ~= current_track then
      print("8120 AUTOMATION DEBUG: *** SWITCHING TRACKS *** " .. current_track .. " → " .. track_index)
      song.selected_track_index = track_index
      print("8120 AUTOMATION DEBUG: *** TRACK SWITCHED *** Now automation is: " .. (song.selected_automation_device and song.selected_automation_device.name or "nil") .. " / " .. (song.selected_automation_parameter and song.selected_automation_parameter.name or "nil"))
      
      -- IMMEDIATELY restore automation to prevent Volume fallback
      if saved_device and saved_param then
        print("8120 AUTOMATION DEBUG: *** IMMEDIATELY RESTORING AUTOMATION *** to prevent Volume fallback")
        PakettiEightOneTwentyRestoreAutomationSelection(saved_device, saved_param, track_index)
      else
        print("8120 AUTOMATION DEBUG: *** NO AUTOMATION TO RESTORE *** - will create Pitchbend")
        -- If no previous automation, create Pitchbend on *Instr. Macros device
        PakettiEightOneTwentyRestoreAutomationSelection(nil, nil, track_index)
      end
    else
      print("8120 AUTOMATION DEBUG: *** ALREADY ON CORRECT TRACK *** " .. track_index)
    end
    
    song.selected_instrument_index = instrument_index
    
    -- Select the primary sample (00-7F velocity range) for this instrument
    local instrument = song.instruments[instrument_index]
    if instrument and instrument.samples then
      local primary_sample_index = PakettiEightOneTwentyFindPrimarySampleIndex(instrument)
      if primary_sample_index then
        song.selected_sample_index = primary_sample_index
      end
    end
    
    local final_device = song.selected_automation_device
    local final_param = song.selected_automation_parameter
    print("8120 AUTOMATION DEBUG: *** AUTOMATION BUTTON COMPLETE *** Final selection: " .. (final_device and final_device.name or "NO_DEVICE") .. " / " .. (final_param and final_param.name or "NO_PARAMETER"))
    renoise.app():show_status(string.format('Row %d: Track "%s" + Instrument "%s" automation: %s / %s', row_index, track.name, instrument.name, (final_device and final_device.name or "NO_DEVICE"), (final_param and final_param.name or "NO_PARAMETER")))
  end


--[[function row_elements.show_macros()
  local instrument_index = row_elements.instrument_popup.value
  local instrument = renoise.song().instruments[instrument_index]
  
  -- Find the active sample (the one with velocity range 00-7F)
  local selected_sample_index = 1
  if instrument and #instrument.samples > 0 then
    for i, sample in ipairs(instrument.samples) do
      local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
      local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
      if velocity_min == 0x00 and velocity_max == 0x7F then
        selected_sample_index = i
        break
      end
    end
  end

  -- Set both instrument and sample
  renoise.song().selected_instrument_index = instrument_index
  renoise.song().selected_sample_index = selected_sample_index
  
  -- Switch views
  renoise.app().window.lower_frame_is_visible = true
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
  renoise.song().selected_track_index = track_indices[track_popup.value]
end
]]--
  -- Define the Reverse Button
  local reverse_button = vb:button{
    text="Reverse",
    notifier=function()
      PakettiEightOneTwentyHighlightRow(row_index)
      row_elements.select_instrument()
      reverse_sample(row_elements)
    end
  }
  local eq30_button = vb:button{
    text="EQ30",
    notifier=function()
      PakettiEightOneTwentyHighlightRow(row_index)
      -- Ensure the correct track and instrument are selected for EQ30 to operate
      local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
      if ti then renoise.song().selected_track_index = ti end
      local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
      if ii then renoise.song().selected_instrument_index = ii end
      if type(PakettiEQ30ShowAndFollow) == "function" then
        PakettiEQ30ShowAndFollow()
      else
        PakettiEQ30LoadAndShowToggle()
      end
    end
  }
  local steppers_button = vb:button{
    text="Steppers",
    notifier=function()
      PakettiEightOneTwentyHighlightRow(row_index)
      local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
      if ti then renoise.song().selected_track_index = ti end
      local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
      if ii then renoise.song().selected_instrument_index = ii end
      if type(PakettiSteppersDialog) == "function" then
        -- Check if steppers dialog is already visible, if so, don't call function (which would close it)
        if not PakettiSteppersDialogIsOpen() then
          PakettiSteppersDialog()
        end
      else
        renoise.app():show_status("PakettiSteppersDialog not available")
      end
    end
  }
  local gater_button = vb:button{
    text = "Gater",
    notifier=function()
      PakettiEightOneTwentyHighlightRow(row_index)
      local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
      if ti then renoise.song().selected_track_index = ti end
      local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
      if ii then renoise.song().selected_instrument_index = ii end
      if type(PakettiGaterLoadAndShow) == "function" then
        PakettiGaterLoadAndShow()
      else
        pakettiGaterDialog()
      end
    end
  }

  -- Row-level Record button (Arm -> Start -> Stop/Finalize)
  local record_button = vb:button{
    text = "Record",
    notifier = (function(idx)
      return function()
        PakettiEightOneTwentyRowRecordToggle(idx)
      end
    end)(row_index)
  }


  -- Define the Row Column Layout
  local solo_checkbox = vb:checkbox{value=false,width=30,notifier=function(value)
    PakettiEightOneTwentyHighlightRow(row_index)
    local prev_device, prev_param = nil, nil
    if renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
      prev_device = renoise.song().selected_automation_device
      prev_param = renoise.song().selected_automation_parameter
    end
    local track_index = track_indices[track_popup.value] or row_index
    local track = renoise.song().tracks[track_index]
    if row_elements and row_elements.updating_solo then return end
    if track then
      track.solo_state = value and true or false
    end
    -- Select the row's track, instrument and 00-7F sample for immediate visual feedback
    if track_index and track_index >= 1 and track_index <= #renoise.song().tracks then
      renoise.song().selected_track_index = track_index
    end
    local instrument_index = row_elements.instrument_popup and row_elements.instrument_popup.value
    if instrument_index and instrument_index >= 1 and instrument_index <= #renoise.song().instruments then
      renoise.song().selected_instrument_index = instrument_index
      local inst = renoise.song().instruments[instrument_index]
      if inst then
        for sample_idx, sample in ipairs(inst.samples) do
          local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
          local vmin = vr and vr[1]
          local vmax = vr and vr[2]
          if vmin == 0x00 and vmax == 0x7F then
            renoise.song().selected_sample_index = sample_idx
            break
          end
        end
      end
    end
    if track_index and prev_device and prev_param then
      PakettiEightOneTwentyRestoreAutomationSelection(prev_device, prev_param, track_index)
    end
    PakettiEightOneTwentyApplySoloMutePolicy()
  end}
  row_elements.solo_checkbox = solo_checkbox

  local mute_label = vb:text{text="Mute",font="bold",style="strong",width=30}
  local solo_label = vb:text{text="Solo",font="bold",style="strong",width=30}

  local labels_row = vb:row{volume_label, vb:space{width=3}, transpose_label}
  local rotaries_row = vb:row{volume_rotary, vb:space{width=3}, transpose_rotary}
  local toggles_labels_row = vb:row{solo_label, vb:space{width=3}, mute_label}
  local toggles_row = vb:row{solo_checkbox, vb:space{width=3}, mute_checkbox}

  local left_controls = vb:column{labels_row, rotaries_row, toggles_labels_row, toggles_row}

  local row = vb:row{
    style = "body",
    left_controls,
    vb:column{
    vb:row{number_buttons_row},
    vb:row(checkbox_row_elements),
    vb:row(yxx_checkbox_row_elements),
    vb:row{
      vb:button{
        text="<",
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          local first_note_value = checkboxes[1].value
          local first_yxx_value = yxx_checkboxes[1].value
          for i = 1, MAX_STEPS - 1 do
            checkboxes[i].value = checkboxes[i + 1].value
            yxx_checkboxes[i].value = yxx_checkboxes[i + 1].value
          end
          checkboxes[MAX_STEPS].value = first_note_value
          yxx_checkboxes[MAX_STEPS].value = first_yxx_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
          --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text=">",
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          local last_note_value = checkboxes[MAX_STEPS].value
          local last_yxx_value = yxx_checkboxes[MAX_STEPS].value
          for i = MAX_STEPS, 2, -1 do
            checkboxes[i].value = checkboxes[i - 1].value
            yxx_checkboxes[i].value = yxx_checkboxes[i - 1].value
          end
          checkboxes[1].value = last_note_value
          yxx_checkboxes[1].value = last_yxx_value
          row_elements.print_to_pattern()
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
         --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text="Clear",
    notifier=function()
      if not initializing then PakettiEightOneTwentyHighlightRow(row_index) end
          if initializing then return end
          row_elements.updating_checkboxes = true
          row_elements.updating_yxx_checkboxes = true
          for i = 1, MAX_STEPS do
            checkboxes[i].value = false
            yxx_checkboxes[i].value = false
          end
          row_elements.updating_checkboxes = false
          row_elements.updating_yxx_checkboxes = false
          row_elements.print_to_pattern()
          renoise.app():show_status("Wiped all steps of row " .. row_index .. ".")
          --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      vb:button{
        text="Random Steps",
        notifier=function()
          PakettiEightOneTwentyHighlightRow(row_index)
          row_elements.randomize()
          renoise.app():show_status("Randomized steps of row " .. row_index .. ".")
         --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        end
      },
      --mute_checkbox,vb:text{text="Mute", font = "bold", style = "strong",width=30},
        instrument_popup,
        vb:button{text="Load", notifier = row_elements.browse_instrument},
        vb:button{text="RandomLoad", notifier=function() 
        local track_popup_value = row_elements.track_popup.value
        local instrument_popup_value = row_index  -- Set instrument based on row number
        local track_index = track_indices[track_popup_value]
        local instrument_index = instrument_popup_value
        renoise.song().selected_track_index = track_index
        renoise.song().selected_instrument_index = instrument_index
      
        local instrument = loadRandomDrumkitSamples(120, nil, false)
        if not instrument then
          return
        end
      
        for _, sample in ipairs(instrument.samples) do
          sample.sample_mapping.base_note = 48
          sample.sample_mapping.note_range = {0, 119}
        end
      
        if renoise.song().tracks[track_index] then
          -- Preserve the 8120 track name format
          local track = renoise.song().tracks[track_index]
                if not track.name:match("^8120_%d+%[%d+%]$") then
        local base_name = string.format("8120_%02d", track_index)
        track.name = string.format("%s[%03d]", base_name, MAX_STEPS)  -- Initialize with MAX_STEPS
      end
  
  -- Add automation device if enabled in preferences
  if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
    -- Remove any existing *Instr. Macros device first
    for i = #track.devices, 1, -1 do
      local device = track.devices[i]
      if device.name == "*Instr. Macros" then
        track:delete_device_at(i)
      end
    end
    -- Add new *Instr. Macros device
    loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
    local macro_device = track:device(#track.devices)
    macro_device.display_name = string.format("%02X_Drumkit", track_index - 1)
    macro_device.is_maximized = false
  end
        else
          renoise.app():show_warning("Selected track does not exist.")
        end
      
        update_instrument_list_and_popups()
        row_elements.slider.value = 1
        pakettiSampleVelocityRangeChoke(1)
        row_elements.update_sample_name_label()
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
      end},
      --vb:button{text="Refresh", notifier = row_elements.refresh_instruments},
      slider,
      vb:button{text="Random", notifier = row_elements.random_button_pressed},
      vb:button{text="Show", notifier = row_elements.select_instrument},
      vb:button{text="Automation", notifier = row_elements.show_automation},
      --      vb:button{text="Macros", notifier=row_elements.show_macros},
      reverse_button, eq30_button, steppers_button, gater_button, record_button,
    
  },
    },
  }

  -- Assign Elements to row_elements Table
  row_elements.checkboxes = checkboxes
  row_elements.yxx_checkboxes = yxx_checkboxes
  row_elements.yxx_valuebox = yxx_valuebox
  row_elements.valuebox = valuebox
  row_elements.slider = slider
  row_elements.track_popup = track_popup
  row_elements.instrument_popup = instrument_popup
  row_elements.mute_checkbox = mute_checkbox
  row_elements.output_delay_slider = output_delay_slider
  row_elements.output_delay_value_label = output_delay_value_label
  row_elements.transpose_rotary = transpose_rotary
  row_elements.volume_rotary = volume_rotary
  row_elements.row_container = row

  -- Initialize the Row
  row_elements.initialize_row()
  if row_elements.attach_mute_observer then row_elements.attach_mute_observer() end
  if row_elements.attach_transpose_observer then row_elements.attach_transpose_observer() end
  if row_elements.attach_solo_observer then row_elements.attach_solo_observer() end
  if row_elements.attach_volume_observer then row_elements.attach_volume_observer() end
  -- Keep beatsync UI in sync when instrument popup changes is handled in the popup's constructor notifier

  return row, row_elements
end

-- Function to create global controls
function create_global_controls()
  play_checkbox = vb:checkbox{value = renoise.song().transport.playing, midi_mapping = "Paketti:Paketti Groovebox 8120:Play Control", notifier=function(value)
    if initializing then return end
    if value then
      renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
    else
      renoise.song().transport:stop()
    end
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  follow_checkbox = vb:checkbox{value = renoise.song().transport.follow_player, notifier=function(value)
    if initializing then return end
    renoise.song().transport.follow_player = value
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}
  groove_enabled_checkbox = vb:checkbox{value = renoise.song().transport.groove_enabled, notifier=function(value)
    if initializing then return end
    renoise.song().transport.groove_enabled = value
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
  end}
  bpm_display = vb:button{text="BPM: " .. tostring(renoise.song().transport.bpm),width=60, tooltip="Clicking on this button will randomize the BPM", notifier = update_bpm}

  local_groove_sliders = {}
  local_groove_labels = {}
  local groove_controls = vb:row{}
  for i = 1, 4 do
    local groove_value = renoise.song().transport.groove_amounts[i] or 0
    local_groove_labels[i] = vb:text{text = string.format("%.0f%%", groove_value * 100), style="strong", font="bold",width=35}
    local_groove_sliders[i] = vb:slider{min = 0.0, max = 1.0, value = groove_value,width=100, notifier=function(value)
      if initializing then return end
      local_groove_labels[i].text = string.format("%.0f%%", value * 100)
      local groove_values = {}
      for j = 1, 4 do
        groove_values[j] = local_groove_sliders[j].value
      end
      renoise.song().transport.groove_amounts = groove_values
      renoise.song().transport.groove_enabled = true
      groove_enabled_checkbox.value = true
      renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
    end}
    groove_controls:add_child(vb:row{local_groove_sliders[i], local_groove_labels[i]})
  end

  random_gate_button = vb:button{ text="Random Gate", midi_mapping="Paketti:Paketti Groovebox 8120:Random Gate", notifier=function()
    if initializing then return end
    random_gate()
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}

  fill_empty_label = vb:text{ text="Fill Empty Steps: 0%", style="strong", font="bold",width=140 }
  fill_empty_slider = vb:slider{min = 0, max = 20, value = 0,width=150, steps = {0.1, -0.1}, midi_mapping="Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider", notifier=function(value)
    if initializing then return end
    fill_empty_label.text="Fill Empty Steps: " .. tostring(math.floor(value)) .. "%"
    if value == 0 then
      clear_all()
    else
      fill_empty_steps(value / 100)
      renoise.app():show_status("Filled empty steps with " .. tostring(math.floor(value)) .. "% probability.")
      --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end
  end}

  local reverse_all_button = vb:button{text="Reverse Samples", midi_mapping="Paketti:Paketti Groovebox 8120:Reverse All", notifier = reverse_all}


local randomize_all_yxx_button = vb:button{
  text="Random Yxx",
  notifier=function()
    trueRandomSeed()
    
    for _, row_elements in ipairs(rows) do
      local random_value = math.random(0, 255)
      row_elements.yxx_slider.value = random_value
      row_elements.yxx_valuebox.value = random_value
      row_elements.print_to_pattern()
    end
    renoise.app():show_status("Randomized Yxx values for all rows.")
  end
}



  -- Create step mode switch
  local step_mode_switch = vb:switch{
    items = {"16 Steps", "32 Steps"},
    width = 150,
    value = (MAX_STEPS == 32) and 2 or 1,
    notifier = function(value)
      local new_max_steps = (value == 2) and 32 or 16
      if new_max_steps ~= MAX_STEPS then
        MAX_STEPS = new_max_steps
        -- Close and reopen dialog with new step count
        if dialog and dialog.visible then
          -- Cleanup BPM observable before closing
          cleanup_bpm_observable()
          dialog:close()
          dialog = nil
          rows = {}
          -- Reopen immediately with new settings
          pakettiEightSlotsByOneTwentyDialog()
        end
        renoise.app():show_status("Switched to " .. new_max_steps .. " steps mode")
      end
    end
  }

  global_controls = vb:column{
    vb:row{
      step_mode_switch,
      vb:text{text=" | ", font = "bold", style = "strong"},
      play_checkbox, vb:text{text="Play", font = "bold", style = "strong",width=30},
      follow_checkbox, vb:text{text="Follow", font = "bold", style = "strong",width=50},
      vb:button{text="/2", notifier = divide_bpm},
      vb:button{text="-", notifier = decrease_bpm},
      bpm_display,
      vb:button{text="+", notifier = increase_bpm},
      vb:button{text="*2", notifier = multiply_bpm},
      random_gate_button,
      vb:button{text="Fetch", midi_mapping="Paketti:Paketti Groovebox 8120:Fetch Pattern", notifier = fetch_pattern},
      fill_empty_label,
      fill_empty_slider}}

  -- Function to check if groovebox tracks exist
  function PakettiGrooveboxCheckTracksExist()
    local song = renoise.song()
    if not song then return false end
    
    local groovebox_tracks_found = 0
    for i = 1, math.min(8, song.sequencer_track_count) do
      if song.tracks[i] and song.tracks[i].name:match("8120_%d+") then
        groovebox_tracks_found = groovebox_tracks_found + 1
      end
    end
    
    return groovebox_tracks_found >= 8
  end

  -- Function to check if groovebox instruments exist (just check for the end marker)
  function PakettiGrooveboxCheckInstrumentsExist()
    local song = renoise.song()
    if not song then return false end
    
    for i = 1, #song.instruments do
      local instrument_name = song.instruments[i].name
      if instrument_name == "=== Groovebox 8120 Ends ===" then
        return true
      end
    end
    
    return false
  end

  -- Function to safely append groovebox tracks
  function PakettiGrooveboxAppendTracks()
    local song = renoise.song()
    if not song then
      renoise.app():show_status("No song available")
      return false
    end
    
    -- Insert 8 tracks at the beginning with proper naming
    for i = 8, 1, -1 do
      song:insert_track_at(1)
      local base_name = string.format("8120_%02d", i)
      song.tracks[1].name = string.format("%s[%03d]", base_name, MAX_STEPS)
    end
    
    renoise.app():show_status("Created 8 Groovebox tracks")
    return true
  end

  -- Function to safely append groovebox instruments (just ensure the end marker exists)
  function PakettiGrooveboxAppendInstruments()
    local song = renoise.song()
    if not song then
      renoise.app():show_status("No song available")
      return false
    end
    
    -- Ensure we have at least 8 instruments
    while #song.instruments < 8 do
      song:insert_instrument_at(#song.instruments + 1)
    end
    
    -- Insert end marker instrument after the first 8 instruments (position 9)
    song:insert_instrument_at(9)
    song.instruments[9].name = "=== Groovebox 8120 Ends ==="
    
    renoise.app():show_status("Created Groovebox end marker")
    return true
  end

  -- Function to safely append groovebox tracks and instruments if needed
  function PakettiGrooveboxSafeAppend()
    if not preferences.PakettiGroovebox8120.AppendTracksAndInstruments.value then
      return
    end
    
    local tracks_exist = PakettiGrooveboxCheckTracksExist()
    local instruments_exist = PakettiGrooveboxCheckInstrumentsExist()
    
    if not tracks_exist then
      PakettiGrooveboxAppendTracks()
    end
    
    if not instruments_exist then
      PakettiGrooveboxAppendInstruments()
    end
    
    if not tracks_exist or not instruments_exist then
      renoise.app():show_status("Groovebox setup completed")
    end
  end

  -- Function to check if first 8 tracks are collapsed
  function PakettiGrooveboxGetFirstEightTracksCollapsedState()
    local song = renoise.song()
    if not song then
      return preferences.PakettiGroovebox8120.Collapse.value
    end
    
    local track_count = math.min(8, song.sequencer_track_count)
    local collapsed_count = 0
    
    for i = 1, track_count do
      if song.tracks[i] and song.tracks[i].collapsed then
        collapsed_count = collapsed_count + 1
      end
    end
    
    -- Return true if more than half are collapsed, or use preference default if no tracks
    if track_count == 0 then
      return preferences.PakettiGroovebox8120.Collapse.value
    end
    return collapsed_count > (track_count / 2)
  end

  -- Function to toggle collapse state of first 8 tracks
  function PakettiGrooveboxCollapseFirstEightTracks(should_collapse)
    local song = renoise.song()
    if not song then
      renoise.app():show_status("No song available")
      return
    end
    
    local track_count = math.min(8, song.sequencer_track_count)
    for i = 1, track_count do
      if song.tracks[i] then
        song.tracks[i].collapsed = should_collapse
      end
    end
    
    local status_text = should_collapse and "Collapsed first 8 tracks" or "Expanded first 8 tracks"
    renoise.app():show_status(status_text)
  end

  local collapse_checkbox = vb:checkbox{
    value = preferences.PakettiGroovebox8120.Collapse.value,
    notifier = function(value)
      PakettiGrooveboxCollapseFirstEightTracks(value)
      -- Update preference to remember user's choice
      preferences.PakettiGroovebox8120.Collapse.value = value
    end
  }

  local global_buttons = vb:row{
    vb:text{text="Global", style="strong", font="bold"},
    vb:button{text="Clear All", notifier = clear_all},
    vb:button{text="Random Steps", midi_mapping="Paketti:Paketti Groovebox 8120:Randomize All", notifier = randomize_all},

    vb:button{text="Random Samples", midi_mapping="Paketti:Paketti Groovebox 8120:Random All", notifier = random_all},

    reverse_all_button,
    randomize_all_yxx_button,
    vb:space{width=8},
    collapse_checkbox,
    vb:text{text="Collapse", style="strong", font="bold"},
    vb:button{
      text="Reset Output Delay",
      notifier=function()
        local song=renoise.song()
        -- Reset all tracks' output delays and update all rows' displays
        for i = 1, 8 do
          song.tracks[i].output_delay = 0
          if rows[i] then
            rows[i].output_delay_slider.value = 0
            rows[i].output_delay_value_label.text = string.format("%+04dms", 0)
          end
        end
      end
    },



    -- Add new Sequential Load button
    vb:button{
      text="Sequential Load",
      notifier=function()
        loadSequentialSamplesWithFolderPrompts()
      end
    },
    vb:button{
      text="Sequential RandomLoad",
      notifier=function()
        loadSequentialDrumkitSamples()
      end
    },
    vb:button{
      text="Sequential RandomLoadAll",
      notifier=function()
        loadSequentialRandomLoadAll()
      end
    },    
  }
  
  local global_groove_controls = vb:row{
    groove_enabled_checkbox, vb:text{text="Global Groove", font = "bold", style = "strong",width=100},
    groove_controls, vb:button{text="Random Groove", midi_mapping="Paketti:Paketti Groovebox 8120:Random Groove", notifier = randomize_groove},
    vb:text{text="|", style="strong", font="bold"},
    vb:button{text="Duplicate Pattern", midi_mapping="Paketti:Paketti Groovebox 8120:Duplicate Pattern", notifier = PakettiEightOneTwentyDuplicatePattern}
  }

  -- Create Global Step Buttons
  local step_values = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "24", "32", "48", "64", "128", "192", "256", "384", "512", "<<", ">>"}
  -- Add 32 to default step values if MAX_STEPS is 32
  if MAX_STEPS == 32 and not table.find(step_values, "32") then
    -- 32 is already in the list, so no need to add it
  end
  global_step_buttons = vb:row{}
  for _, step in ipairs(step_values) do
    global_step_buttons:add_child(vb:button{
      text = step,
      midi_mapping = "Paketti:Paketti Groovebox 8120:Global Step " .. step,
      notifier=function()
        if initializing then return end
        if step == "<<" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local first_note_value = row_elements.checkboxes[1].value
            local first_yxx_value = row_elements.yxx_checkboxes[1].value
            for i = 1, MAX_STEPS - 1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
            end
            row_elements.checkboxes[MAX_STEPS].value = first_note_value
            row_elements.yxx_checkboxes[MAX_STEPS].value = first_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the left.")
        elseif step == ">>" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local last_note_value = row_elements.checkboxes[MAX_STEPS].value
            local last_yxx_value = row_elements.yxx_checkboxes[MAX_STEPS].value
            for i = MAX_STEPS, 2, -1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
            end
            row_elements.checkboxes[1].value = last_note_value
            row_elements.yxx_checkboxes[1].value = last_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the right.")
        else
          set_global_steps(tonumber(step))
        end
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    })
  end

  -- Add random stepcount button (applies random 1-16 to all rows)
  global_step_buttons:add_child(vb:button{
    text = "Rnd Stepcount",
    midi_mapping = "Paketti:Paketti Groovebox 8120:Random Stepcount",
    notifier = function()
      if initializing then return end
      PakettiEightOneTwentyRandomizeStepCounts()
    end
  })

--global_controls:add_child(randomize_all_yxx_button)
  return global_controls, global_groove_controls, global_buttons, global_step_buttons
end


function fetch_pattern()
  if initializing then
    -- Allow fetching during initialization without setting checkboxes to inactive
  else
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = false
      end
      for _, yxx_checkbox in ipairs(row_elements.yxx_checkboxes) do
        yxx_checkbox.active = false
      end
    end
  end

  local pattern = renoise.song().selected_pattern
  
  -- For each row/track, analyze the pattern and store step count
  for i, row_elements in ipairs(rows) do
    -- Get track info and step count from track name
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    local step_count = getStepsFromTrackName(track.name)
    
    -- Set the valuebox to match track name's step count
    row_elements.updating_steps = true
    row_elements.valuebox.value = step_count
    row_elements.updating_steps = false
  
    local track_in_pattern = pattern.tracks[track_index]
    local line_count = pattern.number_of_lines
    local instrument_used = nil
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local yxx_value_found = false

    -- First clear all checkboxes
    for i = 1, MAX_STEPS do
      row_elements.checkboxes[i].value = false
      row_elements.yxx_checkboxes[i].value = false
    end

    -- Now fetch the actual pattern content for the first MAX_STEPS steps
    for line = 1, math.min(line_count, MAX_STEPS) do
      local note_line = track_in_pattern:line(line).note_columns[1]
      local effect_column = track_in_pattern:line(line).effect_columns[1]
      if note_line and note_line.note_string == "C-4" then
        row_elements.checkboxes[line].value = true
        if effect_column and effect_column.number_string == "0Y" then
          row_elements.yxx_checkboxes[line].value = true
          row_elements.yxx_valuebox.value = effect_column.amount_value
          yxx_value_found = true
        else
          row_elements.yxx_checkboxes[line].value = false
        end
        if not instrument_used and not note_line.is_empty then
          instrument_used = note_line.instrument_value
        end
      else
        row_elements.checkboxes[line].value = false
        row_elements.yxx_checkboxes[line].value = false
      end
    end

    if not yxx_value_found then
      row_elements.yxx_valuebox.value = 0x20 -- Initialize to 20 if no Yxx content
    end

    if instrument_used then
      row_elements.instrument_popup.value = instrument_used + 1
    else
      row_elements.instrument_popup.value = i  -- Set default instrument index to row number
    end

    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end

  if not initializing then
    for _, row_elements in ipairs(rows) do
      for _, checkbox in ipairs(row_elements.checkboxes) do
        checkbox.active = true
      end
      for _, yxx_checkbox in ipairs(row_elements.yxx_checkboxes) do
        yxx_checkbox.active = true
      end
    end
  end

  renoise.app():show_status("Pattern fetched successfully.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end



-- Function to reverse sample
function reverse_sample(row_elements)
  local instrument_index = row_elements.instrument_popup.value
  local instrument = renoise.song().instruments[instrument_index]
  if not instrument then
    renoise.app():show_warning("Selected instrument does not exist.")
    return
  end
  local sample_to_reverse = nil
  for _, sample in ipairs(instrument.samples) do
    local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
    local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
    if velocity_min == 0x00 and velocity_max == 0x7F then
      sample_to_reverse = sample
      break
    end
  end
  if not sample_to_reverse or not sample_to_reverse.sample_buffer then
    renoise.app():show_status("No sample to reverse, doing nothing.")
    return
  end
  local sample_buffer = sample_to_reverse.sample_buffer
  local num_channels = sample_buffer.number_of_channels
  local num_frames = sample_buffer.number_of_frames
  if num_channels == 0 or num_frames == 0 then
    renoise.app():show_warning("Selected sample has no channels or frames for this row.")
    return
  end
  sample_buffer:prepare_sample_data_changes()
  for channel = 1, num_channels do
    local channel_data = {}
    for frame = 1, num_frames do
      channel_data[frame] = sample_buffer:sample_data(channel, frame)
    end
    for i = 1, math.floor(num_frames / 2) do
      channel_data[i], channel_data[num_frames - i + 1] = channel_data[num_frames - i + 1], channel_data[i]
    end
    for frame = 1, num_frames do
      sample_buffer:set_sample_data(channel, frame, channel_data[frame])
    end
  end
  sample_buffer:finalize_sample_data_changes()
  local sample_name = sample_to_reverse.name ~= "" and sample_to_reverse.name or "Sample " .. sample_to_reverse.index
  local instrument_name = instrument.name ~= "" and instrument.name or "Instrument " .. instrument_index
  renoise.app():show_status(string.format("Reversed Sample '%s' of Instrument '%s' for Row.", sample_name, instrument_name))
end

-- Function to reverse all samples
function reverse_all()
  if initializing then return end
  local reversed_count = 0
  local reversed_samples = {}
  
  for row_index, row_elements in ipairs(rows) do
    local instrument_index = row_elements.instrument_popup.value
    local instrument = renoise.song().instruments[instrument_index]
    if instrument then
      local sample_to_reverse = nil
      for _, sample in ipairs(instrument.samples) do
        local velocity_min = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[1]
        local velocity_max = sample.sample_mapping and sample.sample_mapping.velocity_range and sample.sample_mapping.velocity_range[2]
        if velocity_min == 0x00 and velocity_max == 0x7F then
          sample_to_reverse = sample
          break
        end
      end
      
      if sample_to_reverse and sample_to_reverse.sample_buffer then
        local sample_buffer = sample_to_reverse.sample_buffer
        local num_channels = sample_buffer.number_of_channels
        local num_frames = sample_buffer.number_of_frames
        
        if num_channels > 0 and num_frames > 0 then
          sample_buffer:prepare_sample_data_changes()
          for channel = 1, num_channels do
            local channel_data = {}
            for frame = 1, num_frames do
              channel_data[frame] = sample_buffer:sample_data(channel, frame)
            end
            for i = 1, math.floor(num_frames / 2) do
              channel_data[i], channel_data[num_frames - i + 1] = channel_data[num_frames - i + 1], channel_data[i]
            end
            for frame = 1, num_frames do
              sample_buffer:set_sample_data(channel, frame, channel_data[frame])
            end
          end
          sample_buffer:finalize_sample_data_changes()
          
          local sample_name = sample_to_reverse.name ~= "" and sample_to_reverse.name or "Sample " .. sample_to_reverse.index
          table.insert(reversed_samples, string.format("%02d: %s", row_index, sample_name))
          reversed_count = reversed_count + 1
        end
      end
    end
  end
  
  if reversed_count > 0 then
    local status_message = string.format("Reversed Sample: %s", table.concat(reversed_samples, " - "))
    renoise.app():show_status(status_message)
  else
    renoise.app():show_status("No samples found to reverse in any instrument.")
  end
end

function random_gate()
  if initializing then return end
  
  trueRandomSeed()
  
  -- Set batch update mode
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    
    -- Update both track name and valuebox
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    updateTrackNameWithSteps(track, MAX_STEPS)  -- Set track name to MAX_STEPS steps
    row_elements.valuebox.value = MAX_STEPS     -- Set valuebox to MAX_STEPS
  end

  -- Prepare all changes in memory first
  local checkbox_states = {}
  -- Remove yxx_states as we don't want to randomize Yxx checkboxes
  
  for i = 1, MAX_STEPS do
    local selected_row = math.random(1, #rows)
    for row_index = 1, #rows do
      if not checkbox_states[row_index] then 
        checkbox_states[row_index] = {}
      end
      checkbox_states[row_index][i] = (row_index == selected_row)
      -- Remove the yxx_states assignment
    end
  end

  -- Apply all changes at once
  for row_index, row_elements in ipairs(rows) do
    for i = 1, MAX_STEPS do
      row_elements.checkboxes[i].value = checkbox_states[row_index][i]
      -- Leave Yxx checkboxes unchanged
    end
  end

  -- Single pattern update at the end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end

  renoise.app():show_status("Step count reset to " .. MAX_STEPS .. ", random gate pattern applied.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to clear all steps
function clear_all()
  if initializing then return end
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    local checkboxes = row_elements.checkboxes
    local yxx_checkboxes = row_elements.yxx_checkboxes
    for i = 1, MAX_STEPS do
      checkboxes[i].value = false
      yxx_checkboxes[i].value = false
    end
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end
  renoise.app():show_status("Wiped all steps of each row.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Function to fill empty steps
function fill_empty_steps(probability)
  if initializing then return end
  trueRandomSeed()
  
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
    for i = 1, MAX_STEPS do
      if not row_elements.checkboxes[i].value then
        row_elements.checkboxes[i].value = math.random() < probability
      end
      if not row_elements.yxx_checkboxes[i].value then
        row_elements.yxx_checkboxes[i].value = math.random() < probability
      end
    end
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
    row_elements.print_to_pattern()
  end
end

-- Function to randomize all samples
function random_all()
  if initializing then return end
  
  -- Check if we have enough instruments
  local song=renoise.song()
  if #song.instruments < 8 then
    renoise.app():show_status(string.format("Not enough instruments. Need 8, but only have %d. Please add more instruments first.", #song.instruments))
    return
  end
  
  -- Check if any instruments have samples
  local has_samples = false
  for i = 1, 8 do
    if song.instruments[i] and #song.instruments[i].samples > 0 then
      has_samples = true
      break
    end
  end
  
  if not has_samples then
    renoise.app():show_status("No samples found in any of the 8 instruments. Please load some samples first.")
    return
  end
  
  -- Now proceed with randomization only if we have samples
  for _, row_elements in ipairs(rows) do
    if row_elements.random_button_pressed then
      row_elements.random_button_pressed()
    else
      renoise.app():show_status("Error: random_button_pressed not found for a row.")
    end
  end
  renoise.app():show_status("Each Instrument Bank now has a Random Selected Sample.")
end

function randomize_all()
  if initializing then return end
  
  trueRandomSeed()
  
  -- First set all rows to update mode
  for _, row_elements in ipairs(rows) do
    row_elements.updating_checkboxes = true
    row_elements.updating_yxx_checkboxes = true
  end
  
  -- Then do all randomization
  for _, row_elements in ipairs(rows) do
    for i = 1, MAX_STEPS do
      row_elements.checkboxes[i].value = math.random() >= 0.5
      row_elements.yxx_checkboxes[i].value = math.random() >= 0.5
    end
  end
  
  -- Finally, update pattern and reset flags
  for _, row_elements in ipairs(rows) do
    row_elements.print_to_pattern()
    row_elements.updating_checkboxes = false
    row_elements.updating_yxx_checkboxes = false
  end
  
  renoise.app():show_status("Each Instrument Row step content has now been randomized.")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function set_global_steps(steps)
  if initializing then return end  
  
  -- Don't set initializing flag, as it prevents pattern printing
  for _, row_elements in ipairs(rows) do
    row_elements.updating_steps = true
    local track_index = track_indices[row_elements.track_popup.value]
    local track = renoise.song():track(track_index)
    updateTrackNameWithSteps(track, steps)
    row_elements.valuebox.value = steps
    -- Only highlight button if step count is different from MAX_STEPS
    -- This prevents default MAX_STEPS from being highlighted as "selected"
    if steps == MAX_STEPS then
      row_elements.selected_step = nil
    else
      row_elements.selected_step = steps
    end
    update_row_button_colors(row_elements)
    row_elements.updating_steps = false
    row_elements.print_to_pattern()
  end
  
  renoise.app():show_status("All step counts set to " .. tostring(steps) .. ".")
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

-- Randomize per-row step counts between 1 and 16 and apply to all rows
function PakettiEightOneTwentyRandomizeStepCounts()
  if initializing then return end
  trueRandomSeed()
  
  local song = renoise.song()
  for _, row_elements in ipairs(rows) do
    row_elements.updating_steps = true
    local random_steps = math.random(1, 16)
    local track_index = track_indices[row_elements.track_popup.value]
    local track = song:track(track_index)
    updateTrackNameWithSteps(track, random_steps)
    row_elements.valuebox.value = random_steps
    -- Do not set selected_step during randomization to avoid forcing a highlight
    row_elements.selected_step = nil
    update_row_button_colors(row_elements)
    row_elements.updating_steps = false
    row_elements.print_to_pattern()
  end
  renoise.app():show_status("Randomized step counts (1-16) for all rows.")
end

-- Function to update BPM display from observable
function update_bpm_display()
  if bpm_display then
    bpm_display.text = "BPM: " .. tostring(renoise.song().transport.bpm)
  end
end

-- Function to setup BPM observable
function setup_bpm_observable()
  -- Remove existing observer if any
  if bpm_observer and renoise.song().transport.bpm_observable:has_notifier(bpm_observer) then
    renoise.song().transport.bpm_observable:remove_notifier(bpm_observer)
  end
  
  -- Add new observer
  bpm_observer = function()
    update_bpm_display()
  end
  
  renoise.song().transport.bpm_observable:add_notifier(bpm_observer)
end

-- Function to cleanup BPM observable
function cleanup_bpm_observable()
  if bpm_observer and renoise.song().transport.bpm_observable:has_notifier(bpm_observer) then
    renoise.song().transport.bpm_observable:remove_notifier(bpm_observer)
    bpm_observer = nil
  end
end

-- Functions to adjust BPM
function increase_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm + 1
  if new_bpm > 999 then new_bpm = 999 end
  renoise.song().transport.bpm = new_bpm
  -- BPM display will be updated automatically by the observable
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function decrease_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm - 1
  if new_bpm < 20 then new_bpm = 20 end
  renoise.song().transport.bpm = new_bpm
  -- BPM display will be updated automatically by the observable
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function divide_bpm()
  if initializing then return end
  local new_bpm = math.floor(renoise.song().transport.bpm / 2)
  if new_bpm < 20 then new_bpm = 20 end
  renoise.song().transport.bpm = new_bpm
  -- BPM display will be updated automatically by the observable
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function multiply_bpm()
  if initializing then return end
  local new_bpm = renoise.song().transport.bpm * 2
  if new_bpm > 999 then new_bpm = 999 end
  renoise.song().transport.bpm = new_bpm
  -- BPM display will be updated automatically by the observable
  --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
end

function update_bpm()
  if initializing then return end
  trueRandomSeed()

  local random_bpm = math.random(20, 300)
  renoise.song().transport.bpm = random_bpm
  -- BPM display will be updated automatically by the observable
  renoise.app():show_status("BPM set to " .. random_bpm)
end

-- Function to randomize groove
function randomize_groove()
  if initializing then return end
  trueRandomSeed()

  local groove_values = {}
  for i = 1, 4 do
    local random_value = math.random()
    if local_groove_sliders and local_groove_sliders[i] then
      local_groove_sliders[i].value = random_value
    end
    if local_groove_labels and local_groove_labels[i] then
      local_groove_labels[i].text = string.format("%d%%", random_value * 100)
    end
    groove_values[i] = random_value
  end
  renoise.song().transport.groove_amounts = groove_values
  renoise.song().transport.groove_enabled = true
  renoise.song().selected_track_index = renoise.song().sequencer_track_count + 1
--  renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
  renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
end

-- Paketti Groovebox 8120 Dialog
function pakettiEightSlotsByOneTwentyDialog()
  -- Check if dialog is already open and close it
  if dialog and dialog.visible then
    -- Cleanup BPM observable before closing
    cleanup_bpm_observable()
    dialog:close()
    dialog = nil
    return
  end

  initializing = true  -- Set initializing flag to true
  local song = renoise.song()
  local prev_selected_track = song.selected_track_index
  local prev_selected_instrument = song.selected_instrument_index

  ensure_instruments_exist()  -- Ensure at least 8 instruments exist
  PakettiEightOneTwentyInit()
  
  -- Ensure a marker instrument named "=== Groovebox 8120 Ends ===" exists once, after instrument 07
  do
    local song = renoise.song()
    local marker_name = "=== Groovebox 8120 Ends ==="
    local found = false
    for i = 1, #song.instruments do
      if song.instruments[i].name == marker_name then
        found = true
        break
      end
    end
    if not found then
      -- We target index 9 (1-based), which is after instrument 07 (index 8)
      local insert_index = 9
      if #song.instruments < insert_index - 1 then
        -- Ensure there are at least 8 instruments first
        while #song.instruments < 8 do
          song:insert_instrument_at(#song.instruments + 1)
        end
      end
      song:insert_instrument_at(insert_index)
      song.instruments[insert_index].name = marker_name
    end
  end
  
  -- Update groovebox tracks that are using old default (16) to new default (MAX_STEPS)
  -- This preserves custom step counts while updating old defaults
  if MAX_STEPS ~= 16 then
    for i = 1, math.min(8, #renoise.song().tracks) do
      local track = renoise.song():track(i)
      if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
        -- Only update tracks that have exactly [016] (old default) to new default
        if track.name:match("^8120_%d+%[016%]$") then
          local base_name = string.format("8120_%02d", i)
          track.name = string.format("%s[%03d]", base_name, MAX_STEPS)
          print(string.format("Updated track %d from [016] to [%03d]", i, MAX_STEPS))
        end
      end
    end
  end


  -- Now rebuild track_names and track_indices
  track_names, track_indices = {}, {}
  for i, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(track_names, track.name)
      table.insert(track_indices, i)
    end
  end

  -- Initialize beatsync foldout visibility from preference before building UI
  if preferences and preferences.PakettiGroovebox8120AdditionalOptions ~= nil then
    local pref_val = preferences.PakettiGroovebox8120AdditionalOptions
    if type(pref_val) == "table" and pref_val.value ~= nil then
      beatsync_visible = pref_val.value and true or false
    else
      beatsync_visible = pref_val and true or false
    end
  end

  local global_controls, global_groove_controls, global_buttons, global_step_buttons = create_global_controls()
  -- Add 'Initialize EQ30' to the top control row
  local init_eq30_button = vb:button{
    text = "Initialize EQ30",
    notifier = function()
      local song = renoise.song()
      if not song then
        renoise.app():show_status("No song available")
        return
      end
      local initialized_count = 0
      local skipped_count = 0
      local max_tracks = math.min(8, #song.tracks)
      for i = 1, max_tracks do
        local trk = song:track(i)
        if trk and trk.type == renoise.Track.TRACK_TYPE_SEQUENCER then
          -- Detect existing EQ30 setup: 4 EQ10 devices named "EQ30 Device *"
          local eq30_named_count = 0
          for di = 1, #trk.devices do
            local dev = trk.devices[di]
            if dev and dev.device_path == "Audio/Effects/Native/EQ 10" then
              local dn = tostring(dev.display_name or "")
              if string.sub(dn, 1, 11) == "EQ30 Device" then
                eq30_named_count = eq30_named_count + 1
              end
            end
          end
          if eq30_named_count >= 4 then
            print(string.format("EQ30 already present on track %d ('%s') - skipping init", i, trk.name))
            skipped_count = skipped_count + 1
          else
            song.selected_track_index = i
            if type(apply_eq30_to_track) == "function" then
              print(string.format("Initializing EQ30 on track %d ('%s')", i, trk.name))
              apply_eq30_to_track()
              initialized_count = initialized_count + 1
            elseif type(PakettiEQ30LoadAndShowToggle) == "function" then
              -- Fallback: add devices if missing and avoid leaving the UI open
              print(string.format("Fallback init via PakettiEQ30LoadAndShowToggle on track %d ('%s')", i, trk.name))
              local dialog_was_visible = (eq_dialog and eq_dialog.visible)
              PakettiEQ30LoadAndShowToggle()
              if eq_dialog and eq_dialog.visible then eq_dialog:close() end
              if dialog_was_visible and PakettiEQ10ExperimentInit then PakettiEQ10ExperimentInit() end
              initialized_count = initialized_count + 1
            else
              print("EQ30 init functions not available")
            end
          end
        end
      end
      renoise.app():show_status(string.format("EQ30: initialized %d track(s), skipped %d existing", initialized_count, skipped_count))
    end
  }
  -- Global Pitch Rotary (top-right)
  local global_pitch_rotary = vb:rotary{
    min = -120,
    max = 120,
    value = 0,
    width = 20,
    height = 20,
    notifier = function(v)
      -- Relative-from-previous behavior: compute delta and apply relative change
      local new_v = math.floor(v)
      local delta = new_v - (gbx_global_pitch_ui_prev_value or 0)
      gbx_global_pitch_ui_prev_value = new_v
      if delta ~= 0 then
        PakettiGrooveboxGlobalPitch(delta)
      end
    end
  }
  local global_pitch_label = vb:text{text="Global Pitch", style="strong", font="bold"}
  local global_pitch_column = vb:row{global_pitch_rotary, global_pitch_label}

  local top_row = vb:row{global_controls, vb:space{width=8}, init_eq30_button, vb:space{width=8}, global_pitch_column}
  local dc = vb:column{top_row, global_groove_controls, global_buttons, global_step_buttons, vb:space{height=8}}
  -- Create and add rows with spacing between them
  for i = 1, 8 do
    if i > 1 then
      -- Add space before each row except the first one
      dc:add_child(vb:space {height = 3})
    end
    local row, elements = PakettiEightSlotsByOneTwentyCreateRow(i)
    dc:add_child(row)
    rows[i] = elements
  end

  -- Beatsync foldout UI: arrow + 8 rows (checkbox + valuebox per instrument)
  local arrow_unique_id = "beatsync_toggle_" .. tostring(os.clock())
  beatsync_content_id = "beatsync_content_" .. tostring(os.clock())
  local arrow_button = vb:button{
    id = arrow_unique_id,
    text = beatsync_visible and "▾" or "▴",
    width = 22,
    notifier = function()
      beatsync_visible = not beatsync_visible
      if vb.views[beatsync_content_id] then vb.views[beatsync_content_id].visible = beatsync_visible end
      vb.views[arrow_unique_id].text = beatsync_visible and "▾" or "▴"
      -- rows is now globally initialized before this point, but guard anyway
      if beatsync_visible and rows and #rows >= 1 then
        for i = 1,8 do PakettiEightOneTwentyUpdateBeatsyncUiFor(i) end
      end
      if preferences and preferences.PakettiGroovebox8120AdditionalOptions ~= nil then
        if type(preferences.PakettiGroovebox8120AdditionalOptions) == "table" and preferences.PakettiGroovebox8120AdditionalOptions.value ~= nil then
          preferences.PakettiGroovebox8120AdditionalOptions.value = beatsync_visible
        else
          preferences.PakettiGroovebox8120AdditionalOptions = beatsync_visible
        end
        if preferences.save_as then preferences:save_as("preferences.xml") end
      end
    end
  }

  local beatsync_row = vb:row{}
  beatsync_checkboxes = {}
  beatsync_valueboxes = {}
  beatsync_updating = {}
  local beatsync_mode_popups = {}

  for i=1,8 do
    local idx = i
    beatsync_updating[idx] = false
    local cb = vb:checkbox{
      value=false,
      tooltip = string.format("Instrument %02d BeatSync On/Off (set to Off when value is 0)", idx),
      notifier=function(value)
        if beatsync_updating[idx] then return end
        local re = rows[idx]
        if not re then return end
        local inst_idx = re.instrument_popup and re.instrument_popup.value
        local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
        if not inst then return end
        local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
        local smp = smp_idx and inst.samples[smp_idx] or nil
        if not smp then return end
        -- Select instrument and sample, show sample editor
        renoise.song().selected_instrument_index = inst_idx
        renoise.song().selected_sample_index = smp_idx
        beatsync_updating[idx] = true
        if value then
          local new_lines = beatsync_valueboxes[idx] and beatsync_valueboxes[idx].value or 64
          if new_lines < 1 then new_lines = 1 end
          if new_lines > 512 then new_lines = 512 end
          smp.beat_sync_lines = new_lines
          smp.beat_sync_enabled = true
        else
          smp.beat_sync_enabled = false
        end
        beatsync_updating[idx] = false
      end
    }
    local vb_lines = vb:valuebox{
      min = 0,
      max = 512,
      value = 0,
      width = 72,
      tooltip = string.format("Instrument %02d BeatSync Lines (0 = Off)", idx),
      notifier=function(val)
        if beatsync_updating[idx] then return end
        local re = rows[idx]
        if not re then return end
        local inst_idx = re.instrument_popup and re.instrument_popup.value
        local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
        if not inst then return end
        local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
        local smp = smp_idx and inst.samples[smp_idx] or nil
        if not smp then return end
        -- Select instrument and sample, show sample editor
        renoise.song().selected_instrument_index = inst_idx
        renoise.song().selected_sample_index = smp_idx
        beatsync_updating[idx] = true
        if val <= 0 then
          smp.beat_sync_enabled = false
          cb.value = false
        else
          if val > 512 then val = 512 end
          smp.beat_sync_lines = val
          smp.beat_sync_enabled = true
          cb.value = true
        end
        beatsync_updating[idx] = false
      end
    }
    beatsync_checkboxes[idx] = cb
    beatsync_valueboxes[idx] = vb_lines
    local col = vb:column{style="body", vb:row{vb:text{text=string.format("%02d", idx), font="bold", style="strong", width=22}, vb_lines, cb}}
    beatsync_adv_columns[idx] = col
    beatsync_row:add_child(col)
  end

  -- BeatSync Mode row (per instrument)
  local beatsync_modes_row = vb:row{}
  local mode_items = {"Repitch","Time-Stretch (Percussion)","Time-Stretch (Texture)"}
  for i=1,8 do
    local idx = i
    local popup = vb:popup{
      items = mode_items,
      width = 90,
      value = (function()
        local v = 1
        if preferences and preferences.PakettiGroovebox8120Beatsync then
          local raw = preferences.PakettiGroovebox8120Beatsync["Mode"..string.format("%02d", idx)]
          if type(raw) == "number" then v = raw
          elseif type(raw) == "table" and raw.value then v = tonumber(raw.value) or 1 end
        end
        if v < 1 or v > 3 then v = 1 end
        return v
      end)(),
      notifier=function(val)
        -- Persist preference
        if preferences and preferences.PakettiGroovebox8120Beatsync then
          preferences.PakettiGroovebox8120Beatsync["Mode"..string.format("%02d", idx)] = val
          preferences:save_as("preferences.xml")
        end
        -- Apply to instrument sample if available
        local re = rows[idx]
        if not re then return end
        local inst_idx = re.instrument_popup and re.instrument_popup.value
        local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
        if not inst then return end
        local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
        local smp = smp_idx and inst.samples[smp_idx] or nil
        if not smp then return end
        -- Select and show
        renoise.song().selected_instrument_index = inst_idx
        renoise.song().selected_sample_index = smp_idx
        -- Map UI value 1..3 directly to API beat_sync_mode
        smp.beat_sync_mode = val
      end
    }
    local col = vb:column{style="body", vb:row{vb:text{text=string.format("%02d", idx), font="bold", style="strong", width=22}, popup}}
    beatsync_adv_columns[idx]:add_child(col)
    beatsync_mode_popups[idx] = popup
    -- Observe beat_sync_mode to reflect external changes
    do
      local re = rows[idx]
      if re then
        local inst_idx = re.instrument_popup and re.instrument_popup.value
        local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
        if inst then
          local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
          local smp = smp_idx and inst.samples[smp_idx] or nil
          if smp and smp.beat_sync_mode_observable then
            local function on_mode_change()
              local v = smp.beat_sync_mode or 1
              if v < 1 or v > 3 then v = 1 end
              popup.value = v
            end
            smp.beat_sync_mode_observable:add_notifier(on_mode_change)
            beatsync_mode_observers[idx] = on_mode_change
          end
        end
      end
    end
  end

  -- Global BeatSync Mode (auto-applies on change to all)
  local global_mode_popup = vb:popup{
    items = mode_items,
    width = 110,
    value = 1,
    notifier=function()
      local val = global_mode_popup.value
      for i=1,8 do
        if preferences and preferences.PakettiGroovebox8120Beatsync then
          preferences.PakettiGroovebox8120Beatsync["Mode"..string.format("%02d", i)] = val
        end
        if beatsync_mode_popups and beatsync_mode_popups[i] then
          beatsync_mode_popups[i].value = val
        end
        local re = rows[i]
        if re then
          local inst_idx = re.instrument_popup and re.instrument_popup.value
          local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
          if inst then
            local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
            local smp = smp_idx and inst.samples[smp_idx] or nil
            if smp then
              smp.beat_sync_mode = val
              smp.beat_sync_enabled = true
              if not smp.beat_sync_lines or smp.beat_sync_lines <= 0 then
                local default_lines = (beatsync_valueboxes and beatsync_valueboxes[i] and beatsync_valueboxes[i].value) or 64
                if default_lines < 1 then default_lines = 64 end
                smp.beat_sync_lines = default_lines
              end
            end
          end
        end
      end
      if preferences and preferences.save_as then preferences:save_as("preferences.xml") end
    end
  }

  -- Shared NNA items (used by global and per-instrument controls)
  local nna_items = {"Cut","Note-Off","Continue"}
  local global_nna_items = {"<None>","Cut","Note-Off","Continue"}
  local nna_popups = {}

  -- Global NNA (auto-applies on change to all)
  local global_nna_popup
  global_nna_popup = vb:popup{
    items = global_nna_items,
    width = 80,
    value = 1,  -- Start at "<None>"
    notifier=function()
      local val = global_nna_popup.value
      
      -- If "<None>" is selected, don't apply anything
      if val == 1 then
        renoise.app():show_status("Global NNA: <None> selected - no changes applied")
        return
      end
      
      -- Convert global popup value to actual NNA value (subtract 1 because of <None> offset)
      local nna_val = val - 1
      local total_samples_affected = 0
      
      for i=1,8 do
        if preferences and preferences.PakettiGroovebox8120Beatsync then
          preferences.PakettiGroovebox8120Beatsync["Nna"..string.format("%02d", i)] = nna_val
        end
        if nna_popups and nna_popups[i] then
          nna_popups[i].value = nna_val
        end
        local re = rows[i]
        if re then
          local inst_idx = re.instrument_popup and re.instrument_popup.value
          local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
          if inst and inst.samples then
            -- Apply NNA to ALL samples in this instrument, not just the primary one
            for sample_idx, sample in ipairs(inst.samples) do
              sample.new_note_action = nna_val
              total_samples_affected = total_samples_affected + 1
            end
          end
        end
      end
      
      local nna_names = {"Cut", "Note-Off", "Continue"}
      local nna_name = nna_names[nna_val] or "Unknown"
      renoise.app():show_status(string.format("Global NNA: Set %s on %d samples across all 8 instruments", nna_name, total_samples_affected))
      
      if preferences and preferences.save_as then preferences:save_as("preferences.xml") end
    end
  }

  -- NNA per-instrument row
  local nna_row = vb:row{}
  local nna_popups = {}
  for i=1,8 do
    local idx = i
    local nna_popup = vb:popup{
      items = nna_items,
      width = 90,
      value = (function()
        local v = 1
        -- Prefer real-time value from current instrument/sample if available
        local re = rows[idx]
        if re then
          local inst_idx = re.instrument_popup and re.instrument_popup.value
          local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
          if inst then
            local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
            local smp = smp_idx and inst.samples[smp_idx] or nil
            if smp and smp.new_note_action then
              v = smp.new_note_action
            end
          end
        end
        -- Fallback to preference when instrument/sample not available
        if v == 1 and preferences and preferences.PakettiGroovebox8120Beatsync then
          local raw = preferences.PakettiGroovebox8120Beatsync["Nna"..string.format("%02d", idx)]
          if type(raw) == "number" then v = raw
          elseif type(raw) == "table" and raw.value then v = tonumber(raw.value) or v end
        end
        if v < 1 or v > 3 then v = 1 end
        return v
      end)(),
      notifier=function(val)
        if preferences and preferences.PakettiGroovebox8120Beatsync then
          preferences.PakettiGroovebox8120Beatsync["Nna"..string.format("%02d", idx)] = val
          preferences:save_as("preferences.xml")
        end
        local re = rows[idx]
        if not re then return end
        local inst_idx = re.instrument_popup and re.instrument_popup.value
        local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
        if not inst then return end
        local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
        local smp = smp_idx and inst.samples[smp_idx] or nil
        if not smp then return end
        renoise.song().selected_instrument_index = inst_idx
        renoise.song().selected_sample_index = smp_idx
        renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR
        smp.new_note_action = val
      end
    }
    local col = vb:column{style="body", vb:row{vb:text{text=string.format("%02d", idx), font="bold", style="strong", width=22}, nna_popup}}
    beatsync_adv_columns[idx]:add_child(col)
    nna_popups[idx] = nna_popup
    -- Attach real-time observer so popup tracks changes outside the UI
    local re = rows[idx]
    if re then
      local inst_idx = re.instrument_popup and re.instrument_popup.value
      local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
      if inst then
        local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(inst)
        local smp = smp_idx and inst.samples[smp_idx] or nil
        if smp and smp.new_note_action_observable then
          local function on_nna_change()
            local v = smp.new_note_action or 1
            if v < 1 or v > 3 then v = 1 end
            nna_popup.value = v
          end
          smp.new_note_action_observable:add_notifier(on_nna_change)
        end
      end
    end
  end

  local beatsync_container = vb:column{
    vb:row{arrow_button, vb:text{text="BeatSync per Instrument (00-7F sample)", font="bold", style="strong"}},
    vb:column{
      id = beatsync_content_id,
      visible = beatsync_visible,
      beatsync_row,
      beatsync_modes_row,
      
      vb:row{nna_row},
      vb:row{vb:text{text="Global Beatsync", font="bold", style="strong", width=60}, global_mode_popup, vb:space{width=8}, vb:text{text="Global NNA", font="bold", style="strong", width=40}, global_nna_popup}
    }
  }
  --dc:add_child(vb:space{height=6})
  dc:add_child(beatsync_container)
  -- Prime BeatSync UI from live song state when foldout starts visible
  if beatsync_visible then
    for i=1,8 do PakettiEightOneTwentyUpdateBeatsyncUiFor(i) end
  end
  fetch_pattern()  -- Call fetch_pattern() to populate GUI elements from the pattern

  -- Safely append groovebox tracks and instruments if needed
  PakettiGrooveboxSafeAppend()

  -- Apply collapse preference setting when dialog opens
  PakettiGrooveboxCollapseFirstEightTracks(preferences.PakettiGroovebox8120.Collapse.value)

  initializing = false  -- Set initializing flag to false after initialization

  for _, row_elements in ipairs(rows) do
    row_elements.update_sample_name_label()
  end
  -- Debug output removed
    local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120", dc, keyhandler)
  
  -- Setup BPM observable after dialog is created
  setup_bpm_observable()
  -- Setup playhead highlight updates after dialog is created
  PakettiEightOneTwentySetupPlayhead()

  -- No post-create visibility toggling required

  -- Attach instruments list observer so newly inserted instruments wire up observers immediately
  if instruments_list_observer and renoise.song().instruments_observable:has_notifier(instruments_list_observer) then
    renoise.song().instruments_observable:remove_notifier(instruments_list_observer)
  end
  instruments_list_observer = function()
    update_instrument_list_and_popups()
    -- Reattach transpose observers for all rows to the new/changed instrument indices
    for i = 1, #rows do
      local re = rows[i]
      if re and re.attach_transpose_observer then
        re.attach_transpose_observer()
      end
      if beatsync_visible then PakettiEightOneTwentyUpdateBeatsyncUiFor(i) end
    end
  end
  renoise.song().instruments_observable:add_notifier(instruments_list_observer)

  -- Ensure Renoise receives keyboard focus per user rule
  renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame

  -- Attach dialog close cleanup via idle watcher (no closed_observable on Dialog)
  local dialog_idle_watcher
  dialog_idle_watcher = function()
    if not dialog or (dialog and not dialog.visible) then
      if rows then
        for i = 1, #rows do
          local re = rows[i]
          if re and re.detach_mute_observer then
            re.detach_mute_observer()
          end
          if re and re.detach_transpose_observer then
            re.detach_transpose_observer()
          end
          if re and re.detach_solo_observer then
            re.detach_solo_observer()
          end
          if re and re.detach_volume_observer then
            re.detach_volume_observer()
          end
        end
      end
      -- Cleanup playhead observers/timer when dialog closes
      PakettiEightOneTwentyCleanupPlayhead()
      -- Detach beatsync observers
      for i=1,8 do PakettiEightOneTwentyDetachBeatsyncObserversFor(i) end
      -- Clear mode observers
      beatsync_mode_observers = {}
      cleanup_bpm_observable()
      -- Persist preferences explicitly on close
      if preferences and preferences.save_as then
        preferences:save_as("preferences.xml")
      end
      -- Clear local BeatSync state tables; do not touch vb.views (read-only)
      beatsync_checkboxes = {}
      beatsync_valueboxes = {}
      beatsync_updating = {}
      if instruments_list_observer and renoise.song().instruments_observable:has_notifier(instruments_list_observer) then
        renoise.song().instruments_observable:remove_notifier(instruments_list_observer)
        instruments_list_observer = nil
      end
      if dialog_idle_watcher and renoise.tool().app_idle_observable:has_notifier(dialog_idle_watcher) then
        renoise.tool().app_idle_observable:remove_notifier(dialog_idle_watcher)
      end
      dialog_idle_watcher = nil
    end
  end
  if not renoise.tool().app_idle_observable:has_notifier(dialog_idle_watcher) then
    renoise.tool().app_idle_observable:add_notifier(dialog_idle_watcher)
  end
  -- Restore original selection to avoid unexpected focus changes on open
  if prev_selected_track and prev_selected_track >= 1 and prev_selected_track <= #song.tracks then
    song.selected_track_index = prev_selected_track
  end
  if prev_selected_instrument and prev_selected_instrument >= 1 and prev_selected_instrument <= #song.instruments then
    song.selected_instrument_index = prev_selected_instrument
  end
end



function assign_midi_mappings()
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Play Control",invoke=function(message)
    if message:is_trigger() then
      if not renoise.song().transport.playing then
        renoise.song().transport:start(renoise.Transport.PLAYMODE_RESTART_PATTERN)
      else
        renoise.song().transport:stop()
      end
    end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Fill",invoke=function(message)
    if message:is_trigger() then random_fill() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Gate",invoke=function(message)
    if message:is_trigger() then random_gate() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Fetch Pattern",invoke=function(message)
    if message:is_trigger() then fetch_pattern() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider",invoke=function(message)
    if message:is_abs_value() then
      fill_empty_slider.value = message.int_value * 100 / 127
    end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random All",invoke=function(message)
    if message:is_trigger() then random_all() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Randomize All",invoke=function(message)
    if message:is_trigger() then randomize_all() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Groove",invoke=function(message)
    if message:is_trigger() then randomize_groove() end
  end}
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Reverse All",invoke=function(message)
    if message:is_trigger() then reverse_all() end
  end}

  -- MIDI mapping for randomizing stepcounts across all rows
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Random Stepcount",invoke=function(message)
    if message:is_trigger() then PakettiEightOneTwentyRandomizeStepCounts() end
  end}

  local step_button_names = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "24", "32", "48", "64", "128", "192", "256", "384", "512", "<<", ">>"}
  for _, step in ipairs(step_button_names) do
    renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Step " .. step,invoke=function(message)
      if message:is_trigger() then
        if step == "<<" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local first_note_value = row_elements.checkboxes[1].value
            local first_yxx_value = row_elements.yxx_checkboxes[1].value
            for i = 1, MAX_STEPS - 1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
            end
            row_elements.checkboxes[MAX_STEPS].value = first_note_value
            row_elements.yxx_checkboxes[MAX_STEPS].value = first_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the left.")
        elseif step == ">>" then
          for _, row_elements in ipairs(rows) do
            row_elements.updating_checkboxes = true
            row_elements.updating_yxx_checkboxes = true
            local last_note_value = row_elements.checkboxes[MAX_STEPS].value
            local last_yxx_value = row_elements.yxx_checkboxes[MAX_STEPS].value
            for i = MAX_STEPS, 2, -1 do
              row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
              row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
            end
            row_elements.checkboxes[1].value = last_note_value
            row_elements.yxx_checkboxes[1].value = last_yxx_value
            row_elements.print_to_pattern()
            row_elements.updating_checkboxes = false
            row_elements.updating_yxx_checkboxes = false
          end
          renoise.app():show_status("All steps shifted to the right.")
        else
          set_global_steps(tonumber(step))
        end
        --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
      end
    end}
  end

  for row = 1, 8 do
    for step = 1, MAX_STEPS do
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%d Step%d", row, step),invoke=function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements and row_elements.checkboxes[step] then
            row_elements.checkboxes[step].value = not row_elements.checkboxes[step].value
          end
        end
      end}
    end
    local buttons = {"<", ">", "Clear", "Randomize", "Load", "Show", "Random", "Automation", "Reverse"}
    for _, btn in ipairs(buttons) do
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%d %s", row, btn),invoke=function(message)
        if message:is_trigger() then
          local row_elements = rows[row]
          if row_elements then
            if btn == "<" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              local first_note_value = row_elements.checkboxes[1].value
              local first_yxx_value = row_elements.yxx_checkboxes[1].value
              for i = 1, MAX_STEPS - 1 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i + 1].value
                row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i + 1].value
              end
              row_elements.checkboxes[MAX_STEPS].value = first_note_value
              row_elements.yxx_checkboxes[MAX_STEPS].value = first_yxx_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted left.", row))
            elseif btn == ">" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              local last_note_value = row_elements.checkboxes[MAX_STEPS].value
              local last_yxx_value = row_elements.yxx_checkboxes[MAX_STEPS].value
              for i = MAX_STEPS, 2, -1 do
                row_elements.checkboxes[i].value = row_elements.checkboxes[i - 1].value
                row_elements.yxx_checkboxes[i].value = row_elements.yxx_checkboxes[i - 1].value
              end
              row_elements.checkboxes[1].value = last_note_value
              row_elements.yxx_checkboxes[1].value = last_yxx_value
              row_elements.print_to_pattern()
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              renoise.app():show_status(string.format("Row %d: Steps shifted right.", row))
            elseif btn == "Clear" then
              row_elements.updating_checkboxes = true
              row_elements.updating_yxx_checkboxes = true
              for i = 1, MAX_STEPS do
                row_elements.checkboxes[i].value = false
                row_elements.yxx_checkboxes[i].value = false
              end
              row_elements.updating_checkboxes = false
              row_elements.updating_yxx_checkboxes = false
              row_elements.print_to_pattern()
              renoise.app():show_status(string.format("Row %d: All steps cleared.", row))
            elseif btn == "Randomize" then
              row_elements.randomize()
              renoise.app():show_status(string.format("Row %d: Steps randomized.", row))
            elseif btn == "Load" then
              row_elements.browse_instrument()
            elseif btn == "Show" then
              row_elements.select_instrument()
            elseif btn == "Random" then
              row_elements.random_button_pressed()
            elseif btn == "Automation" then
              row_elements.show_automation()
--            elseif btn == "Macros" then 
--              row_elements.show_macros()
            elseif btn == "Reverse" then
              reverse_sample(row_elements)
            end
          end
        end
      end}
    end
  end
  
  -- Sample slider MIDI mappings for each row (works with or without dialog)
  for row = 1, 8 do
    renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%d Sample Slider", row),invoke=function(message)
      if not message:is_abs_value() then return end
      local slider_value = math.floor((message.int_value / 127) * 119) + 1
      local song = renoise.song()
      -- If dialog row exists, use existing slider logic and also select sample immediately
      if rows and rows[row] and rows[row].slider then
        rows[row].slider.value = slider_value
        -- Also explicitly select track/instrument/sample to reflect change instantly
        if row <= #song.tracks and song:track(row).type == renoise.Track.TRACK_TYPE_SEQUENCER then
          song.selected_track_index = row
        end
        if row <= #song.instruments then
          song.selected_instrument_index = row
          local inst = song.instruments[row]
          if inst and inst.samples and #inst.samples > 0 then
            local idx = slider_value
            if idx > #inst.samples then idx = #inst.samples end
            if idx < 1 then idx = 1 end
            if inst.samples[1] and inst.samples[1].slice_markers and #inst.samples[1].slice_markers > 0 then
              song.selected_sample_index = 1
            else
              song.selected_sample_index = idx
            end
          end
        end
        return
      end
      -- Headless: select track/instrument matching the row and apply selection
      local track_index = row
      if track_index <= #song.tracks and song:track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
        song.selected_track_index = track_index
      end
      local instrument_index = row
      if instrument_index <= #song.instruments then
        song.selected_instrument_index = instrument_index
        local inst = song.instruments[instrument_index]
        if inst and inst.samples and #inst.samples > 0 then
          local idx = slider_value
          if idx > #inst.samples then idx = #inst.samples end
          if idx < 1 then idx = 1 end
          -- Respect slice rule: if first sample has slices, select only sample 1
          if inst.samples[1] and inst.samples[1].slice_markers and #inst.samples[1].slice_markers > 0 then
            song.selected_sample_index = 1
          else
            song.selected_sample_index = idx
          end
          -- Ensure velocity mapping choke
          if type(pakettiSampleVelocityRangeChoke) == "function" then
            pakettiSampleVelocityRangeChoke(song.selected_sample_index)
          end
        end
      end
    end}
  end
end

assign_midi_mappings()

-- Add MIDI mapping for step mode switch
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Toggle Step Mode (16/32)",invoke=function(message)
  if message:is_trigger() then
    -- Toggle between 16 and 32 steps
    MAX_STEPS = (MAX_STEPS == 16) and 32 or 16
    -- If dialog is open, refresh it
    if dialog and dialog.visible then
      -- Cleanup BPM observable before closing
      cleanup_bpm_observable()
      dialog:close()
      dialog = nil
      rows = {}
      pakettiEightSlotsByOneTwentyDialog()
    end
    renoise.app():show_status("Toggled to " .. MAX_STEPS .. " steps mode")
  end
end}

function GrooveboxShowClose()
  if dialog and dialog.visible then
    -- Cleanup BPM observable before closing
    cleanup_bpm_observable()
    dialog:close()
    dialog = nil
    rows = {}
  else pakettiEightSlotsByOneTwentyDialog() end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120",invoke=function() GrooveboxShowClose() end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120",invoke=function(message) if message:is_trigger() then GrooveboxShowClose() end end }

-- Duplicate current pattern below and jump to it (no clearing of muted tracks)
function PakettiEightOneTwentyDuplicatePattern()
  local song=renoise.song()
  local current_pattern_index=song.selected_pattern_index
  local current_sequence_index=song.selected_sequence_index
  local new_sequence_index = current_sequence_index + 1
  local new_pattern_index = song.sequencer:insert_new_pattern_at(new_sequence_index)
  song.patterns[new_pattern_index]:copy_from(song.patterns[current_pattern_index])
  local original_name = song.patterns[current_pattern_index].name
  if original_name == "" then
    original_name = "Pattern " .. tostring(current_pattern_index)
  end
  song.patterns[new_pattern_index].name = original_name .. " (duplicate)"
  song.selected_sequence_index = new_sequence_index
  -- Copy mute states from original sequence slot to the new one
  for track_index = 1, #song.tracks do
    local is_muted = song.sequencer:track_sequence_slot_is_muted(track_index, current_sequence_index)
    song.sequencer:set_track_sequence_slot_is_muted(track_index, new_sequence_index, is_muted)
  end
  -- Copy automation data explicitly to ensure full duplication
  for track_index = 1, #song.tracks do
    local original_track = song.patterns[current_pattern_index].tracks[track_index]
    local new_track = song.patterns[new_pattern_index].tracks[track_index]
    for _, automation in ipairs(original_track.automation) do
      local parameter = automation.dest_parameter
      local new_automation = new_track:find_automation(parameter)
      if not new_automation then
        new_automation = new_track:create_automation(parameter)
      end
      new_automation:copy_from(automation)
    end
  end
  renoise.app():show_status("Duplicated pattern below and jumped to it.")
end

-- MIDI mapping and keybinding for Duplicate Pattern button in Groovebox 8120
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Duplicate Pattern",invoke=function(message)
  if message:is_trigger() then PakettiEightOneTwentyDuplicatePattern() end
end}
renoise.tool():add_keybinding{name="Pattern Sequencer:Paketti:Duplicate Pattern (Groovebox 8120)",invoke=PakettiEightOneTwentyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Matrix:Paketti:Duplicate Pattern (Groovebox 8120)",invoke=PakettiEightOneTwentyDuplicatePattern}
renoise.tool():add_keybinding{name="Pattern Editor:Paketti:Duplicate Pattern (Groovebox 8120)",invoke=PakettiEightOneTwentyDuplicatePattern}
renoise.tool():add_keybinding{name="Global:Paketti:Duplicate Pattern (Groovebox 8120)",invoke=PakettiEightOneTwentyDuplicatePattern}

-- Global Pitch Button: adjust transpose for all 8 groovebox instruments
gbx_transpose_baseline = gbx_transpose_baseline or {nil,nil,nil,nil,nil,nil,nil,nil}

local function PakettiGrooveboxCaptureTransposeBaseline()
  local song = renoise.song()
  for row = 1, 8 do
    local row_elements = rows and rows[row] or nil
    local inst_idx = nil
    if row_elements and row_elements.instrument_popup then
      inst_idx = row_elements.instrument_popup.value
    else
      inst_idx = row
    end
    local inst = (inst_idx and song.instruments[inst_idx]) or nil
    gbx_transpose_baseline[row] = inst and (inst.transpose or 0) or 0
  end
end

function PakettiGrooveboxGlobalPitch(delta_semitones)
  local song = renoise.song()
  for row = 1, 8 do
    local row_elements = rows and rows[row] or nil
    local inst_idx = nil
    if row_elements and row_elements.instrument_popup then
      inst_idx = row_elements.instrument_popup.value
    else
      inst_idx = row
    end
    local inst = song.instruments[inst_idx]
    if inst then
      local new_transpose = (inst.transpose or 0) + delta_semitones
      if new_transpose < -120 then new_transpose = -120 end
      if new_transpose > 120 then new_transpose = 120 end
      inst.transpose = new_transpose
      if row_elements and row_elements.transpose_rotary then
        local ui_val = new_transpose
        if ui_val < -64 then ui_val = -64 end
        if ui_val > 64 then ui_val = 64 end
        row_elements.updating_transpose = true
        row_elements.transpose_rotary.value = ui_val
        row_elements.updating_transpose = false
      end
    end
  end
end

function PakettiGrooveboxGlobalPitchAbsolute(absolute_offset)
  local song = renoise.song()
  if not (gbx_transpose_baseline and gbx_transpose_baseline[1] ~= nil) then
    PakettiGrooveboxCaptureTransposeBaseline()
  end
  for row = 1, 8 do
    local row_elements = rows and rows[row] or nil
    local inst_idx = nil
    if row_elements and row_elements.instrument_popup then
      inst_idx = row_elements.instrument_popup.value
    else
      inst_idx = row
    end
    local inst = song.instruments[inst_idx]
    if inst then
      local base_val = gbx_transpose_baseline[row] or (inst.transpose or 0)
      local target = base_val + absolute_offset
      if target < -120 then target = -120 end
      if target > 120 then target = 120 end
      inst.transpose = target
      if row_elements and row_elements.transpose_rotary then
        local ui_val = target
        if ui_val < -64 then ui_val = -64 end
        if ui_val > 64 then ui_val = 64 end
        row_elements.updating_transpose = true
        row_elements.transpose_rotary.value = ui_val
        row_elements.updating_transpose = false
      end
    end
  end
end

-- MIDI mappings for Global Pitch Button
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Pitch Up [Trigger]",invoke=function(message)
  if message:is_trigger() then PakettiGrooveboxGlobalPitch(1) end
end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Pitch Down [Trigger]",invoke=function(message)
  if message:is_trigger() then PakettiGrooveboxGlobalPitch(-1) end
end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Pitch [Relative]",invoke=function(message)
  if message:is_rel_value() then
    local step = 0
    if message.int_value > 0 then step = 1 elseif message.int_value < 0 then step = -1 end
    if step ~= 0 then PakettiGrooveboxGlobalPitch(step) end
  elseif message:is_abs_value() then
    -- Treat absolute 0..127 as relative delta from previous absolute
    local v = message.int_value
    if gbx_global_pitch_midi_prev_abs == nil then
      gbx_global_pitch_midi_prev_abs = v
    end
    local delta = v - gbx_global_pitch_midi_prev_abs
    gbx_global_pitch_midi_prev_abs = v
    if delta ~= 0 then PakettiGrooveboxGlobalPitch(delta) end
  end
end}

-- Absolute global pitch (baseline + offset)
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Pitch [Absolute]",invoke=function(message)
  if message:is_abs_value() then
    -- Still support absolute-to-baseline by mapping 0..127 to -120..+120
    local v = message.int_value
    local offset = math.floor(((v / 127) * 240) - 120)
    PakettiGrooveboxGlobalPitchAbsolute(offset)
  elseif message:is_trigger() then
    -- On trigger, capture a fresh baseline
    PakettiGrooveboxCaptureTransposeBaseline()
  end
end}

-- Debug function removed to reduce console noise


function PakettiEightOneTwentyInit()
  local song=renoise.song()
  local editmodestate = song.transport.edit_mode
  song.transport.edit_mode = true
  
  -- Count sequencer tracks in first 8 positions
  local sequencer_tracks = 0
  local needs_initialization = false
  for i = 1, math.min(8, #song.tracks) do
    if song:track(i).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      sequencer_tracks = sequencer_tracks + 1
      -- Check if track needs initialization (doesn't have correct base name format)
      if not song:track(i).name:match("^8120_%d+%[%d+%]$") then
        needs_initialization = true
      end
    end
  end

  -- Only change track if we need to initialize AND we're not in automation view
  local in_automation = (renoise.app().window.active_lower_frame == renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION)
  if needs_initialization and not in_automation then
    song.selected_track_index = 1
  end

  -- Add any missing sequencer tracks at position 1
  while sequencer_tracks < 8 do
    local next_track_number = sequencer_tracks + 1
    song:insert_track_at(next_track_number)
    song:track(next_track_number).name = string.format("8120_%02d[%03d]", next_track_number, MAX_STEPS)
    sequencer_tracks = sequencer_tracks + 1
  end

  -- Only initialize track names if they don't follow the correct format
  for i = 1, 8 do
    local track = song:track(i)
    if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      -- Only change name if it doesn't match our format
      if not track.name:match("^8120_%d+%[%d+%]$") then
        local base_name = string.format("8120_%02d", i)
        track.name = string.format("%s[%03d]", base_name, MAX_STEPS)  -- Initialize with MAX_STEPS
      end
    end
  end

  song.transport.edit_mode = editmodestate
end


renoise.tool():add_keybinding{name="Global:Paketti:Initialize for Groovebox 8120",invoke=function() 
PakettiEightOneTwentyInit()
end}

-- Function to load samples sequentially from 8 folders with nice prompts (regular samples)
function loadSequentialSamplesWithFolderPrompts()
  local folders = {}
  local current_folder = 1
  local dialog = nil
  local status_labels = {}
  
  -- Helper function to get just filename from path
  local function getFilename(filepath)
    return filepath:match("([^/\\]+)%.%w+$") or filepath:match("([^/\\]+)$") or filepath
  end
  
  -- Function to process a single instrument (regular sample loading)
  local function processInstrument(instrument_index, folder_path)
    local song = renoise.song()
    song.selected_track_index = instrument_index
    song.selected_instrument_index = instrument_index
    local instrument = song.selected_instrument
    
    -- Get all valid audio files in the directory
    local sample_files = PakettiGetFilesInDirectory(folder_path)
    if #sample_files == 0 then
      return false, "No audio files found in folder " .. folder_path
    end

    -- Clear existing samples
    for i = #instrument.samples, 1, -1 do
      instrument:delete_sample_at(i)
    end
    
    -- Load up to 120 samples from the folder
    local max_samples = 120
    local num_samples_to_load = math.min(#sample_files, max_samples)
    
    for i = 1, num_samples_to_load do
      local selected_file = sample_files[i]
      
      instrument:insert_sample_at(i)
      local sample_buffer = instrument.samples[i].sample_buffer
      
      if sample_buffer then
        local success = pcall(function()
          sample_buffer:load_from(selected_file)
          instrument.samples[i].name = getFilename(selected_file)
          -- Set basic mapping
          instrument.samples[i].sample_mapping.base_note = 48
          instrument.samples[i].sample_mapping.note_range = {0, 119}
        end)
        
        if success then
          -- Apply Paketti Loader preferences to the sample
          local sample = instrument.samples[i]
          if preferences then
            if preferences.pakettiLoaderAutofade then sample.autofade = preferences.pakettiLoaderAutofade.value end
            if preferences.pakettiLoaderAutoseek then sample.autoseek = preferences.pakettiLoaderAutoseek.value end
            if preferences.pakettiLoaderInterpolation then sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value end
            if preferences.pakettiLoaderOverSampling then sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value end
            if preferences.pakettiLoaderOneshot then sample.oneshot = preferences.pakettiLoaderOneshot.value end
            if preferences.pakettiLoaderNNA then 
              sample.new_note_action = preferences.pakettiLoaderNNA.value 
            else 
              sample.new_note_action = 1  -- Default to Cut if no preference set
            end
            if preferences.pakettiLoaderLoopMode then sample.loop_mode = preferences.pakettiLoaderLoopMode.value end
            if preferences.pakettiLoaderLoopExit then sample.loop_release = preferences.pakettiLoaderLoopExit.value end
          end
        else
          print(string.format("Failed to load sample %d: %s", i, selected_file))
        end
      end
      
      -- Update status display
      if dialog and dialog.visible and status_labels[instrument_index] then
        local display_name = getFilename(selected_file)
        if #display_name > 60 then
          display_name = display_name:sub(1, 57) .. "..."
        end
        status_labels[instrument_index].text = string.format("Part %d/8: Loading sample %03d/%03d: %s", 
          instrument_index, i, num_samples_to_load, display_name)
      end
      
      if i % 5 == 0 then
        coroutine.yield()
      end
    end
    
    -- Set instrument name
    local folder_name = getFilename(folder_path)
    instrument.name = string.format("8120_%02d %s", instrument_index, folder_name)
    
    return true
  end

  -- Main processing function
  local function process()

    for i = 1, 8 do
      -- Update status to show which part is processing
      for j = i + 1, 8 do
        if status_labels[j] then
          local folder_name = getFilename(folders[j])
          status_labels[j].text = string.format("Part %d/8: Queued - Loading from %s", j, folder_name)
        end
      end
      
      local success, error = processInstrument(i, folders[i])
      if not success then
        print(error)
      end
      
      coroutine.yield()
    end
    
    -- Close dialog and finish up
    if dialog and dialog.visible then
      dialog:close()
    end
    
    -- Apply final settings and update UI
    for i = 1, 8 do
      local instrument = renoise.song():instrument(i)
      if instrument and #instrument.samples > 0 then
        -- Set first sample to full velocity range, others to 0-0
        for sample_idx, sample in ipairs(instrument.samples) do
          sample.sample_mapping.velocity_range = {0, 0}
        end
        instrument.samples[1].sample_mapping.velocity_range = {0, 127}
      end
    end
    
    update_instrument_list_and_popups()
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
  end

  -- Function to start the processing
  local function startProcessing()
    -- Create ProcessSlicer
    local slicer = ProcessSlicer(process)
    
    -- Create progress dialog with status for all 8 parts
    local vb = renoise.ViewBuilder()
    local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
    local DEFAULT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
    
    local dialog_content = vb:column{
      margin = DEFAULT_MARGIN,
      spacing = DEFAULT_SPACING,
    }
    
    -- Add status labels for all 8 parts
    for i = 1, 8 do
      local folder_name = getFilename(folders[i])
      local status_label = vb:text{
        text = string.format("Part %d/8: Queued - Loading from %s", i, folder_name),
        font = "bold",
        style = "strong"
      }
      status_labels[i] = status_label
      dialog_content:add_child(status_label)
    end
    
    dialog_content:add_child(vb:button{
      text = "Cancel",
      width = 80,
      notifier = function()
        slicer:cancel()
        if dialog and dialog.visible then
          dialog:close()
        end
        renoise.app():show_status("Sequential loading cancelled by user")
      end
    })
    
    -- Show dialog
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Sequential Load Progress", dialog_content, keyhandler)
    
    -- Start processing
    slicer:start()
  end

  -- Function to prompt for next folder
  local function promptNextFolder()
    local folder_path = renoise.app():prompt_for_path(string.format("Select folder %d of 8 for Sequential Load.", current_folder))
    if folder_path then
      folders[current_folder] = folder_path
      local folder_name = getFilename(folder_path)
      renoise.app():show_status(string.format("Selected folder %d/8: %s", current_folder, folder_name))
      current_folder = current_folder + 1
      if current_folder <= 8 then
        return promptNextFolder()
      else
        -- All folders selected, start processing
        renoise.app():show_status("All folders selected, starting sequential load...")
        startProcessing()
      end
    else
      -- User cancelled folder selection
      if dialog and dialog.visible then
        dialog:close()
      end
      renoise.app():show_status("Sequential loading cancelled - folder selection aborted")
      return
    end
  end

  -- Start by prompting for folders
  promptNextFolder()
end

-- Function to load samples sequentially from 8 folders using ProcessSlicer
function loadSequentialDrumkitSamples()
  local folders = {}
  local current_folder = 1
  local slicer = nil
  local dialog = nil
  local vb = nil
  local status_labels = {}
  
  -- Helper function to get just filename from path
  local function getFilename(filepath)
    return filepath:match("([^/\\]+)%.%w+$") or filepath
  end
  
  -- Helper function to get file size
  local function getFileSize(filepath)
    local file = io.open(filepath, "rb")
    if file then
      local size = file:seek("end")
      file:close()
      return size
    end
    return 0
  end
  
  -- Helper function to format file size
  local function formatFileSize(size)
    local units = {'B', 'KB', 'MB', 'GB'}
    local unit_index = 1
    while size > 1024 and unit_index < #units do
      size = size / 1024
      unit_index = unit_index + 1
    end
    return string.format("%.2f %s", size, units[unit_index])
  end
  
  -- Helper function to cap filename length
  local function capFilename(filename)
    if #filename > 80 then
      return filename:sub(1, 77) .. "..."
    end
    return filename
  end

  -- Function to add *Instr. Macros device to a track
  local function addInstrMacrosToTrack(track_index)
    local song=renoise.song()
    -- First select the matching instrument
    song.selected_instrument_index = track_index
    -- Then select the track
    song.selected_track_index = track_index
    
    if song.selected_track.type ~= renoise.Track.TRACK_TYPE_MASTER then -- Don't add to master track
      -- Remove any existing *Instr. Macros device first
      for i = #song.selected_track.devices, 1, -1 do
        local device = song.selected_track.devices[i]
        if device.name == "*Instr. Macros" then
          song.selected_track:delete_device_at(i)
        end
      end
      -- Add new *Instr. Macros device
      loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
      local macro_device = song.selected_track:device(#song.selected_track.devices)
      macro_device.display_name = string.format("%02X_Drumkit", track_index - 1)
      macro_device.is_maximized = false
      
      -- Print debug info
      print(string.format("Added *Instr. Macros to track %d, linked to instrument %d", track_index, song.selected_instrument_index))
    end
  end
  
  -- Function to process a single instrument
  local function processInstrument(instrument_index, folder_path)
    -- Get all valid audio files in the directory
    local sample_files = PakettiGetFilesInDirectory(folder_path)
    if #sample_files == 0 then
      print(string.format("ERROR: No audio files found in folder: %s", folder_path))
      return false, "No audio files found in folder " .. folder_path
    end

    -- Set up the instrument
    local song=renoise.song()
    song.selected_track_index = instrument_index
    song.selected_instrument_index = instrument_index
    local instrument = song.selected_instrument
    
    -- Load the default drumkit instrument
    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    renoise.app():load_instrument(defaultInstrument)
    
    -- Update instrument reference and name
    instrument = song.selected_instrument
    instrument.name = string.format("8120_%02d Kit", instrument_index)
    instrument.macros_visible = true

    -- Load samples
    local max_samples = 120
    local num_samples_to_load = math.min(#sample_files, max_samples)
    local failed_files = {}
    
    for i = 1, num_samples_to_load do
      local random_index = math.random(1, #sample_files)
      local selected_file = sample_files[random_index]
      table.remove(sample_files, random_index)
      
      local file_size = getFileSize(selected_file)

      if #instrument.samples < i then
        instrument:insert_sample_at(i)
      end
      
      local load_failed = false
      local error_msg = ""
      
      -- Try to load the sample
      local ok = pcall(function()
        local buffer = instrument.samples[i].sample_buffer
        if not buffer then
          load_failed = true
          error_msg = "No sample buffer available"
          return
        end
        
        -- Attempt to load and catch any errors
        local load_ok, load_err = buffer:load_from(selected_file)
        if not load_ok then
          load_failed = true
          error_msg = load_err or "Unknown error during load_from"
          return
        end
        
        -- Set the name only if load succeeded
        instrument.samples[i].name = getFilename(selected_file)
      end)

      -- Apply Paketti Loader preferences if loading succeeded
      if ok and not load_failed then
        local sample = instrument.samples[i]
        if preferences then
          if preferences.pakettiLoaderAutofade then sample.autofade = preferences.pakettiLoaderAutofade.value end
          if preferences.pakettiLoaderAutoseek then sample.autoseek = preferences.pakettiLoaderAutoseek.value end
          if preferences.pakettiLoaderInterpolation then sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value end
          if preferences.pakettiLoaderOverSampling then sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value end
          if preferences.pakettiLoaderOneshot then sample.oneshot = preferences.pakettiLoaderOneshot.value end
          if preferences.pakettiLoaderNNA then 
            sample.new_note_action = preferences.pakettiLoaderNNA.value 
          else 
            sample.new_note_action = 1  -- Default to Cut if no preference set
          end
          if preferences.pakettiLoaderLoopMode then sample.loop_mode = preferences.pakettiLoaderLoopMode.value end
          if preferences.pakettiLoaderLoopExit then sample.loop_release = preferences.pakettiLoaderLoopExit.value end
        end
      end

      -- Check both pcall result and our own error flag
      if not ok or load_failed then
        print(string.format("FAILED TO LOAD SAMPLE Part %d [%d/%d]: PATH: %s SIZE: %s", 
          instrument_index, i, num_samples_to_load, selected_file, formatFileSize(file_size)))
        
        table.insert(failed_files, {
          index = i,
          path = selected_file,
          size = file_size,
          error = error_msg
        })
      end

      -- Update status display
      if dialog and dialog.visible then
        local display_name = capFilename(getFilename(selected_file))
        status_labels[instrument_index].text = string.format("Part %d/8: Loading sample %03d/%03d: %s", 
          instrument_index, i, num_samples_to_load, display_name)
        status_labels[instrument_index].font = "bold"
        status_labels[instrument_index].style = "strong"
      end
      
      if i % 5 == 0 then
        coroutine.yield()
      end
    end

    -- Print summary of failed files at the end
    if #failed_files > 0 then
      print(string.format("\nSUMMARY: Part %d had %d failed loads:", instrument_index, #failed_files))
      for _, fail in ipairs(failed_files) do
        print(string.format("Sample [%d/%d]: PATH: %s SIZE: %s", 
          fail.index, num_samples_to_load, fail.path, formatFileSize(fail.size)))
      end
      print("----------------------------------------")
    end

    return true
  end

  -- Main processing function for ProcessSlicer
  local function process()

    for i = 1, 8 do
      if slicer:was_cancelled() then
        renoise.app():show_status("Sequential loading cancelled")
        break
      end
      
      -- Update status to show which part is processing
      for j = i + 1, 8 do
        local folder_name = getFilename(folders[j])
        status_labels[j].text = string.format("Part %d/8: Queued - Random from %s", j, folder_name)
        status_labels[j].font = "bold"
        status_labels[j].style = "strong"
      end
      
      local success, error = processInstrument(i, folders[i])
      if not success then
        print(error)
      end
      
      coroutine.yield()
    end
    
    -- Close dialog and finish up
    if dialog and dialog.visible then
      dialog:close()
    end
    
    -- Apply final settings and update UI
    for i = 1, 8 do
      local instrument = renoise.song():instrument(i)
      if instrument then
        -- First set all samples to velocity 0-0
        for sample_idx, sample in ipairs(instrument.samples) do
          sample.sample_mapping.velocity_range = {0, 0}
          -- Set base note and note range for all samples
          sample.sample_mapping.base_note = 48
          sample.sample_mapping.note_range = {0, 119}
        end
        -- Then set first sample to full velocity range
        if #instrument.samples > 0 then
          instrument.samples[1].sample_mapping.velocity_range = {0, 127}
        end
      -- Add *Instr. Macros device to each track if enabled in preferences
      if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
          renoise.song().selected_track_index = i
          addInstrMacrosToTrack(i)
        end
      end
    
    end
    
    update_instrument_list_and_popups()
    -- Switch back to pattern editor when done
   --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
  end

  -- Function to start the processing
  local function startProcessing()
    -- Create ProcessSlicer
    slicer = ProcessSlicer(process)
    
    -- Create progress dialog with status for all 8 parts
    local vb = renoise.ViewBuilder()
    local DEFAULT_MARGIN=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
    local DEFAULT_SPACING=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
    
    local dialog_content = vb:column{
      margin=DEFAULT_MARGIN,
      spacing=DEFAULT_SPACING,
    }
    
    -- Add status labels for all 8 parts
    for i = 1, 8 do
      local folder_name = getFilename(folders[i])
      local status_label = vb:text{
        text = string.format("Part %d/8: Queued - Random from %s", i, folder_name),
        font = "bold",
        style = "strong"
      }
      status_labels[i] = status_label
      dialog_content:add_child(status_label)
    end
    
    dialog_content:add_child(vb:button{
      text="Cancel",
      width=80,
      notifier=function()
        slicer:cancel()
        if dialog and dialog.visible then
          dialog:close()
        end
        renoise.app():show_status("Sequential loading cancelled by user")
      end
    })
    
    -- Show dialog
    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Sequential Load Progress Dialog", dialog_content, keyhandler)
    
    -- Start processing
    slicer:start()
  end

  -- Function to prompt for next folder
  local function promptNextFolder()
    local folder_path = renoise.app():prompt_for_path(string.format("Select folder %d of 8 for Sequential Random Load", current_folder))
    if folder_path then
      folders[current_folder] = folder_path
      local folder_name = getFilename(folder_path)
      renoise.app():show_status(string.format("Selected folder %d/8: %s", current_folder, folder_name))
      current_folder = current_folder + 1
      if current_folder <= 8 then
        return promptNextFolder()
      else
        -- All folders selected, start processing
        renoise.app():show_status("All folders selected, starting sequential load...")
        startProcessing()
      end
    else
      -- User cancelled folder selection
      if dialog and dialog.visible then
        dialog:close()
      end
      renoise.app():show_status("Sequential loading cancelled - folder selection aborted")
      return
    end
  end

  -- Start by prompting for folders
  promptNextFolder()
end

-- Function to load samples sequentially from ONE folder for all 8 parts (RandomLoadAll)
function loadSequentialRandomLoadAll()
  local base_folder = renoise.app():prompt_for_path("Select a single base folder for RandomLoadAll (used for all 8 parts)")
  if not base_folder then
    renoise.app():show_status("RandomLoadAll cancelled - no folder selected")
    return
  end

  -- Seed the random number generator with current time for truly random results
  math.randomseed(os.time())
  -- Add some additional random calls to further randomize the sequence
  math.random(); math.random(); math.random()

  local folders = {}
  for i = 1, 8 do
    folders[i] = base_folder
  end

  -- Reuse the same ProcessSlicer UI and worker pattern as loadSequentialDrumkitSamples,
  -- but without prompting per-part. This is effectively the same as loadSequentialDrumkitSamples
  -- with identical folder input for every part.

  local slicer = nil
  local dialog = nil
  local vb = nil
  local status_labels = {}

  local function getFilename(filepath)
    return filepath:match("([^/\\]+)%.%w+$") or filepath
  end

  local function getFileSize(filepath)
    local file = io.open(filepath, "rb")
    if file then
      local size = file:seek("end")
      file:close()
      return size
    end
    return 0
  end

  local function formatFileSize(size)
    local units = {'B','KB','MB','GB'}
    local unit_index = 1
    while size > 1024 and unit_index < #units do
      size = size / 1024
      unit_index = unit_index + 1
    end
    return string.format("%.2f %s", size, units[unit_index])
  end

  local function capFilename(filename)
    if #filename > 80 then
      return filename:sub(1, 77) .. "..."
    end
    return filename
  end

  local function addInstrMacrosToTrack(track_index)
    local song=renoise.song()
    song.selected_instrument_index = track_index
    song.selected_track_index = track_index
    if song.selected_track.type ~= renoise.Track.TRACK_TYPE_MASTER then
      for i = #song.selected_track.devices, 1, -1 do
        local device = song.selected_track.devices[i]
        if device.name == "*Instr. Macros" then
          song.selected_track:delete_device_at(i)
        end
      end
      loadnative("Audio/Effects/Native/*Instr. Macros", nil, nil, nil, true)
      local macro_device = song.selected_track:device(#song.selected_track.devices)
      macro_device.display_name = string.format("%02X_Drumkit", track_index - 1)
      macro_device.is_maximized = false
    end
  end

  local function processInstrument(instrument_index, folder_path)
    local sample_files = PakettiGetFilesInDirectory(folder_path)
    if #sample_files == 0 then
      print(string.format("ERROR: No audio files found in folder: %s", folder_path))
      return false, "No audio files found in folder " .. folder_path
    end

    local song=renoise.song()
    song.selected_track_index = instrument_index
    song.selected_instrument_index = instrument_index
    local instrument = song.selected_instrument

    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    renoise.app():load_instrument(defaultInstrument)
    instrument = song.selected_instrument
    instrument.name = string.format("8120_%02d Kit", instrument_index)
    instrument.macros_visible = true

    local max_samples = 120
    local num_samples_to_load = math.min(#sample_files, max_samples)
    local failed_files = {}

    for i = 1, num_samples_to_load do
      local random_index = math.random(1, #sample_files)
      local selected_file = sample_files[random_index]
      table.remove(sample_files, random_index)

      local file_size = getFileSize(selected_file)

      if #instrument.samples < i then
        instrument:insert_sample_at(i)
      end

      local load_failed = false
      local error_msg = ""

      local ok = pcall(function()
        local buffer = instrument.samples[i].sample_buffer
        if not buffer then
          load_failed = true
          error_msg = "No sample buffer available"
          return
        end
        local load_ok, load_err = buffer:load_from(selected_file)
        if not load_ok then
          load_failed = true
          error_msg = load_err or "Unknown error during load_from"
          return
        end
        instrument.samples[i].name = getFilename(selected_file)
      end)

      -- Apply Paketti Loader preferences if loading succeeded
      if ok and not load_failed then
        local sample = instrument.samples[i]
        if preferences then
          if preferences.pakettiLoaderAutofade then sample.autofade = preferences.pakettiLoaderAutofade.value end
          if preferences.pakettiLoaderAutoseek then sample.autoseek = preferences.pakettiLoaderAutoseek.value end
          if preferences.pakettiLoaderInterpolation then sample.interpolation_mode = preferences.pakettiLoaderInterpolation.value end
          if preferences.pakettiLoaderOverSampling then sample.oversample_enabled = preferences.pakettiLoaderOverSampling.value end
          if preferences.pakettiLoaderOneshot then sample.oneshot = preferences.pakettiLoaderOneshot.value end
          if preferences.pakettiLoaderNNA then 
            sample.new_note_action = preferences.pakettiLoaderNNA.value 
          else 
            sample.new_note_action = 1  -- Default to Cut if no preference set
          end
          if preferences.pakettiLoaderLoopMode then sample.loop_mode = preferences.pakettiLoaderLoopMode.value end
          if preferences.pakettiLoaderLoopExit then sample.loop_release = preferences.pakettiLoaderLoopExit.value end
        end
      end

      if not ok or load_failed then
        print(string.format("FAILED TO LOAD SAMPLE Part %d [%d/%d]: PATH: %s SIZE: %s",
          instrument_index, i, num_samples_to_load, selected_file, formatFileSize(file_size)))
        table.insert(failed_files, {index=i, path=selected_file, size=file_size, error=error_msg})
      end

      if dialog and dialog.visible then
        local display_name = capFilename(getFilename(selected_file))
        status_labels[instrument_index].text = string.format("Part %d/8: Loading sample %03d/%03d: %s",
          instrument_index, i, num_samples_to_load, display_name)
        status_labels[instrument_index].font = "bold"
        status_labels[instrument_index].style = "strong"
      end

      if i % 5 == 0 then
        coroutine.yield()
      end
    end

    if #failed_files > 0 then
      print(string.format("\nSUMMARY: Part %d had %d failed loads:", instrument_index, #failed_files))
      for _, fail in ipairs(failed_files) do
        print(string.format("Sample [%d/%d]: PATH: %s SIZE: %s",
          fail.index, num_samples_to_load, fail.path, formatFileSize(fail.size)))
      end
      print("----------------------------------------")
    end

    return true
  end

  local function process()
    for i = 1, 8 do
      if slicer:was_cancelled() then
        renoise.app():show_status("Sequential loading cancelled")
        break
      end

      for j = i + 1, 8 do
        local folder_name = getFilename(folders[j])
        status_labels[j].text = string.format("Part %d/8: Queued - Random from %s", j, folder_name)
        status_labels[j].font = "bold"
        status_labels[j].style = "strong"
      end

      local success, error = processInstrument(i, folders[i])
      if not success then
        print(error)
      end

      coroutine.yield()
    end

    if dialog and dialog.visible then
      dialog:close()
    end

    for i = 1, 8 do
      local instrument = renoise.song():instrument(i)
      if instrument then
        for sample_idx, sample in ipairs(instrument.samples) do
          sample.sample_mapping.velocity_range = {0, 0}
          sample.sample_mapping.base_note = 48
          sample.sample_mapping.note_range = {0, 119}
        end
        if #instrument.samples > 0 then
          instrument.samples[1].sample_mapping.velocity_range = {0, 127}
        end
        if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
          renoise.song().selected_track_index = i
          addInstrMacrosToTrack(i)
        end
      end
    end

    update_instrument_list_and_popups()
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
  end

  local function startProcessing()
    slicer = ProcessSlicer(process)
    local vb = renoise.ViewBuilder()
    local DEFAULT_MARGIN=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
    local DEFAULT_SPACING=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

    local dialog_content = vb:column{margin=DEFAULT_MARGIN, spacing=DEFAULT_SPACING}
    for i = 1, 8 do
      local folder_name = getFilename(folders[i])
      local status_label = vb:text{ text = string.format("Part %d/8: Queued - Random from %s", i, folder_name), font = "bold", style = "strong" }
      status_labels[i] = status_label
      dialog_content:add_child(status_label)
    end
    dialog_content:add_child(vb:button{ text = "Cancel", width = 80, notifier = function()
      slicer:cancel()
      if dialog and dialog.visible then dialog:close() end
      renoise.app():show_status("Sequential loading cancelled by user")
    end})

    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Sequential Load Progress Dialog", dialog_content, keyhandler)
    slicer:start()
  end

  startProcessing()
end

-- Groovebox-specific Expand Selection Replicate function
function PakettiGroovebox8120ExpandSelectionReplicate(track_number)
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  -- If track_number is provided, switch to that track
  if track_number then
    if track_number <= #s.tracks and s.tracks[track_number].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_number
      Deselect_All()
      MarkTrackMarkPattern()
      renoise.song().selected_instrument_index = track_number
      
    else
      renoise.app():show_status("Track " .. track_number .. " is not a valid sequencer track")
      return
    end
  end
  
  local currentLine = s.selected_line_index
  
  if s.selection_in_pattern == nil then
    renoise.app():show_status("Nothing selected to Expand, doing nothing.")
    return
  end
  
  local sl = s.selection_in_pattern.start_line
  local el = s.selection_in_pattern.end_line
  local st = s.selection_in_pattern.start_track
  local et = s.selection_in_pattern.end_track
  local nl = s.selected_pattern.number_of_lines
  
  -- Calculate the original and new selection lengths
  local original_length = el - sl + 1
  local new_end_line = el * 2
  if new_end_line > nl then
    new_end_line = nl
  end
  
  -- First pass: Expand the selection
  for tr = st, et do
    for l = el, sl, -1 do
      if l ~= sl then
        local new_line = (l * 2) - sl
        if new_line <= nl then
          local cur_pattern = s:pattern(s.selected_pattern_index)
          local cur_track = cur_pattern:track(tr)
          cur_track:line(new_line):copy_from(cur_track:line(l))
          cur_track:line(l):clear()
          if new_line + 1 <= s.selected_pattern.number_of_lines then
            cur_track:line(new_line + 1):clear()
          end
        end
      end
    end
  end
  
  -- Update selection to include expanded area
  local expanded_length = new_end_line - sl + 1
  s.selection_in_pattern = {start_line=sl, start_track=st, end_track=et, end_line = new_end_line}
  floodfill_with_selection()
  local doiwantthis=false
  -- Restore original track if track_number was provided
  if track_number and original_track <= #s.tracks and doiwantthis==true then
    s.selected_track_index = original_track
    renoise.app():show_status(string.format("Groovebox 8120: Expanded and replicated selection on track %d", track_number))
  else
    renoise.app():show_status(string.format("Groovebox 8120: Expanded and replicated selection from line %d to %d", sl, nl))
  end
  
  -- Sync with groovebox
  if dialog and dialog.visible then
    fetch_pattern()
  end
end

-- Groovebox-specific Shrink Selection Replicate function
function PakettiGroovebox8120ShrinkSelectionReplicate(track_number)
  local s = renoise.song()
  local original_track = s.selected_track_index
  
  -- If track_number is provided, switch to that track
  if track_number then
    if track_number <= #s.tracks and s.tracks[track_number].type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track_index = track_number
      Deselect_All()
      MarkTrackMarkPattern()
      renoise.song().selected_instrument_index = track_number
      
    else
      renoise.app():show_status("Track " .. track_number .. " is not a valid sequencer track")
      return
    end
  end
  
  local currentLine = s.selected_line_index
  
  if s.selection_in_pattern == nil then
    renoise.app():show_status("Nothing selected to Shrink, doing nothing.")
    return
  else
    local sl = s.selection_in_pattern.start_line
    local el = s.selection_in_pattern.end_line
    local st = s.selection_in_pattern.start_track
    local et = s.selection_in_pattern.end_track
    local nl = s.selected_pattern.number_of_lines
    
    for tr = st, et do
      for l = sl, el, 2 do
        if l ~= sl then
          -- Calculate new_line as an integer
          local new_line = math.floor(l / 2 + sl / 2)
          
          -- Ensure new_line is within valid range
          if new_line >= 1 and new_line <= nl then
            local cur_pattern = s:pattern(s.selected_pattern_index)
            local cur_track = cur_pattern:track(tr)
            cur_track:line(new_line):copy_from(cur_track:line(l))
            cur_track:line(l):clear()
            if l + 1 <= s.selected_pattern.number_of_lines then
              cur_track:line(l + 1):clear()
            end
          end
        end
      end
    end

    -- Update selection to include shrunken area and trigger replication
    local new_end_line = math.min(math.floor((el - sl) / 2) + sl, nl)
    s.selection_in_pattern = {start_line=sl, start_track=st, end_track=et, end_line=new_end_line}
    floodfill_with_selection()
    local doiwantthis=false
    -- Restore original track if track_number was provided
    if track_number and original_track <= #s.tracks and doiwantthis==true then
      s.selected_track_index = original_track
      renoise.app():show_status(string.format("Groovebox 8120: Shrank and replicated selection on track %d", track_number))
    else
      renoise.app():show_status(string.format("Groovebox 8120: Shrank and replicated selection from line %d to %d", sl, nl))
    end
    
    -- Sync with groovebox
    if dialog and dialog.visible then
      fetch_pattern()
    end
  end
end

-- Add MIDI mappings for groovebox-specific functions
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120 Expand Selection Replicate [Trigger]",invoke=function(message)
  if message:is_trigger() then
    PakettiGroovebox8120ExpandSelectionReplicate()
  end
end}

renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120 Shrink Selection Replicate [Trigger]",invoke=function(message)
  if message:is_trigger() then
    PakettiGroovebox8120ShrinkSelectionReplicate()
  end
end}

-- Individual track MIDI mappings for groovebox-specific functions
for i=1,8 do
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120 Expand Selection Replicate Track " .. i .. " [Trigger]",invoke=function(message)
    if message:is_trigger() then
      PakettiGroovebox8120ExpandSelectionReplicate(i)
    end
  end}
  
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120 Shrink Selection Replicate Track " .. i .. " [Trigger]",invoke=function(message)
    if message:is_trigger() then
      PakettiGroovebox8120ShrinkSelectionReplicate(i)
    end
  end}
end

-- Groovebox-specific instrument transpose function
local function set_groovebox_instrument_transpose(instrument_index, message)
  local song = renoise.song()
  -- Check if the instrument exists (Lua is 1-indexed, but we receive 0-based indices)
  local instrument = song.instruments[instrument_index + 1]
  if not instrument then
    renoise.app():show_status("Groovebox 8120: Instrument " .. string.format("%02d", instrument_index) .. " does not exist")
    return
  end
  
  -- Map the MIDI message value (0-127) to transpose range (-64 to 64)
  local transpose_value = math.floor((message.int_value / 127) * 128 - 64)
  instrument.transpose = math.max(-64, math.min(transpose_value, 64))
  
  -- Update groovebox rotary if dialog is open and row exists
  if dialog and dialog.visible and rows[instrument_index + 1] and rows[instrument_index + 1].transpose_rotary then
    local ui_val = transpose_value
    if ui_val < -64 then ui_val = -64 end
    if ui_val > 64 then ui_val = 64 end
    rows[instrument_index + 1].transpose_rotary.value = ui_val
  end
  
  -- Select the instrument and track
  song.selected_instrument_index = instrument_index + 1
  song.selected_track_index = instrument_index + 1
  
  -- Status update for debugging
  renoise.app():show_status(string.format("%02d", instrument_index) .. "  " .. instrument.transpose)
end


-- MIDI mappings for groovebox-specific instrument transpose
for i=0,7 do
  renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120 Instrument 0" .. i .." Transpose (-64-+64)",
    invoke=function(message) 
      set_groovebox_instrument_transpose(i, message)
    end}
end
