-- Paketti Groovebox 8120 Script

-- Configuration: Maximum steps per row (16 or 32)

local MAX_STEPS = 16  -- Can be changed dynamically via UI switch
-- Globals used across features (declare early, avoid overengineering)
gbx_transpose_baseline = {nil,nil,nil,nil,nil,nil,nil,nil}
gbx_global_pitch_ui_prev_value = 0
gbx_global_pitch_midi_prev_abs = nil

-- Output Mode: "pattern", "phrase", "phrase_trigger"
-- pattern = write to pattern (original behavior)
-- phrase = write to phrase (creates phrases per row)
-- phrase_trigger = write phrase triggers (Zxx commands per row)
PakettiEightOneTwentyOutputMode = "pattern"
--
-- NOTE: Step mode can be changed dynamically:
-- 1. Use the "16 Steps / 32 Steps" switch in the groovebox interface
-- 2. The UI will automatically recreate with the new step count
-- 3. All checkboxes, buttons, and step logic will adapt
-- 4. Pattern writing and fetching will work with the selected step count

-- Add this line right after stored_step_counts
local sequential_load_current_row = 1

-- Forward declarations for the canvas view module at the bottom of this file.
-- Defined here so file-local helpers above (e.g. the playhead update loop)
-- can reference them without tripping Renoise's strict-globals __index.
local cv_dialog, cv_canvas, cv_ui

-- Forward-declared here (initialized further down) so functions defined above
-- the initialization block (e.g. PakettiEightOneTwentyRowRecordToggle) capture
-- these file-locals as upvalues instead of hitting the strict-globals __index.
local track_names, track_indices, instrument_names

-- BPM observable tracking
local bpm_observer = nil
local instruments_list_observer = nil
local beatsync_visible = false

-- Beatsync UI/observer state
local beatsync_checkboxes = {}
local beatsync_valueboxes = {}
local beatsync_updating = {}
local beatsync_enabled_observers = {}
local beatsync_lines_observers = {}
local beatsync_attached_inst_index = {}
local beatsync_attached_sample_index = {}
local beatsync_mode_observers = {}
local beatsync_mode_popups = {}
-- Advanced (Beatsync + NNA) columns for per-row highlighting
beatsync_adv_columns = {}
-- Baseline for absolute global pitch control (already initialized above)

-- Per-row recording state for Groovebox 8120
gbx_record_phase = {0,0,0,0,0,0,0,0} -- 0=idle, 1=recording
gbx_prev_sample_count = {0,0,0,0,0,0,0,0}
gbx_record_instrument_index = {0,0,0,0,0,0,0,0}

-- Return keyboard focus to Renoise's middle frame after interacting with any
-- 8120 control (checkbox/knob/slider/valuebox). Clicking a control in the tool
-- dialog steals keyboard focus, which would otherwise swallow Renoise global
-- shortcuts like Shift-V (load plugin) and Shift-A (load device). Re-assigning
-- active_middle_frame to itself hands focus back to Renoise without changing
-- which frame is shown.
function PakettiEightOneTwentyReturnFocus()
  local w = renoise.app().window
  w.active_middle_frame = w.active_middle_frame
end

-- Map the just-recorded take to 00-7F (others to 00-00), select it, enable the
-- convenience flags, refresh the row's sample-name label, and re-point the
-- per-row beatsync controls at it.
--
-- Renoise commits the recorded sample ASYNCHRONOUSLY: when recording stops the
-- new slot and its audio may not exist yet, so we only act once a data-bearing
-- sample is actually present. Returns true when the take has been finalized,
-- false when nothing is ready yet (so the caller's poll loop keeps trying).
-- Idempotent: re-running after success is a harmless no-op-equivalent.
function PakettiEightOneTwentyFinalizeRecordedSample(row_index, target_inst_index)
  local song = renoise.song()
  if not song then return false end
  local inst = target_inst_index and song.instruments[target_inst_index] or nil
  if not inst or #inst.samples == 0 then return false end

  -- The recorded take is the highest-index sample that actually carries audio.
  local new_index
  for si = #inst.samples, 1, -1 do
    local smp = inst.samples[si]
    local buf = smp and smp.sample_buffer
    if buf and buf.has_sample_data then new_index = si break end
  end
  if not new_index then
    -- Recorded audio not committed yet — let the poll loop retry.
    return false
  end

  -- Wait for the REAL recorded name. Right after recording, the take still
  -- carries the Paketti chassis placeholder name ("Placeholder sample"); Renoise
  -- renames it to the actual recorded name ("Recorded sample NN") a moment later.
  -- If we finalized now we'd name the instrument "Placeholder sample". So if the
  -- name is still empty or the placeholder, return false and let the poll loop
  -- wait until the real name arrives.
  do
    local rec_name = inst.samples[new_index].name
    if not rec_name or rec_name == "" or rec_name == "Placeholder sample" then
      return false
    end
  end

  song.selected_instrument_index = target_inst_index
  song.selected_sample_index = new_index

  -- Set velocity mapping: recorded sample 00-7F, others 00-00
  for si = 1, #inst.samples do
    local smp = inst.samples[si]
    if smp and smp.sample_mapping and not smp.sample_mapping.read_only then
      smp.sample_mapping.velocity_range = (si == new_index) and {0x00, 0x7F} or {0x00, 0x00}
    end
  end

  if inst.samples[new_index] then
    inst.samples[new_index].autoseek = true
    inst.samples[new_index].autofade = true
    -- Inject the recorded take INTO the Paketti chassis: point it at the
    -- instrument's modulation set (the pitch-bend envelope loaded with the
    -- Paketti Default Instrument) so the recorded sample is Pakettified.
    -- Guarded: only when a modulation set exists.
    -- See features/groovebox-8120-record-pakettified-instrument.feature.
    if inst.sample_modulation_sets and #inst.sample_modulation_sets > 0 then
      pcall(function() inst.samples[new_index].modulation_set_index = 1 end)
    end
    -- Name the instrument after the recorded sample, so the slot reads e.g.
    -- "recorded sample 02" instead of the default chassis name (12st_Pitchbend).
    local recorded_name = inst.samples[new_index].name
    if recorded_name and recorded_name ~= "" then
      inst.name = recorded_name
    end
  end

  -- Refresh the row's sample-name label so it stops showing "No sample available"
  -- once the recorded sample exists, and re-point the per-row beatsync
  -- controls/observers at the recorded sample so toggling beatsync (here or in
  -- the Sample List) reflects on the recorded take and the checkbox becomes
  -- active.
  local re = rows and rows[row_index]
  if re and re.update_sample_name_label then
    re.update_sample_name_label()
  end
  -- The instrument was just renamed after the recorded sample, so refresh the
  -- row instrument popups to show the new name instead of the chassis name.
  if type(update_instrument_list_and_popups) == "function" then
    pcall(update_instrument_list_and_popups)
  end
  if beatsync_visible then
    PakettiEightOneTwentyUpdateBeatsyncUiFor(row_index)
  end
  -- Trigger the freshly recorded sample on the next play by enabling this row's
  -- first step — but only if the row currently has no active steps, so we never
  -- disturb a pattern the user already programmed. Setting the checkbox value
  -- fires its notifier, which writes the note into the pattern.
  if re and re.checkboxes and #re.checkboxes > 0 then
    local any_on = false
    for _, c in ipairs(re.checkboxes) do
      if c.value then any_on = true break end
    end
    if not any_on and re.checkboxes[1] then
      re.checkboxes[1].value = true
    end
  end
  return true
end

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

  -- Two-phase toggle, matching the obvious mental model: the first press opens
  -- the sample recorder AND starts recording; the second press stops recording
  -- and finalizes (maps the take, refreshes the label, activates beatsync). The
  -- old three-press flow (open -> start -> stop) meant a take recorded with
  -- Renoise's own record button never advanced this state to "stop", so finalize
  -- never ran and the row never updated.
  local phase = gbx_record_phase[row_index] or 0
  if phase == 0 then
    -- Pakettified record: load a FRESH Paketti Default Instrument chassis into
    -- this row's instrument slot before recording, so the take lands inside a
    -- Pakettified instrument (pitch-bend modulation, *Instr. Macros). Each
    -- Record press starts from a clean chassis (replaces whatever was in the
    -- slot). See features/groovebox-8120-record-pakettified-instrument.feature.
    if ii then
      if song.selected_instrument_index ~= ii then song.selected_instrument_index = ii end
      if type(pakettiPreferencesDefaultInstrumentLoader) == "function" then
        pakettiPreferencesDefaultInstrumentLoader()
      end
    end
    -- Start: open the sample recorder and begin recording immediately.
    local inst = song.instruments[ii]
    gbx_prev_sample_count[row_index] = (inst and #inst.samples or 0)
    gbx_record_instrument_index[row_index] = ii or 0
    renoise.app().window.sample_record_dialog_is_visible = true
    renoise.app().window.active_middle_frame = renoise.app().window.active_middle_frame
    song.transport:start_stop_sample_recording()
    gbx_record_phase[row_index] = 1
    renoise.app():show_status(string.format("8120 Row %02d: Recording… Press Record again to stop.", row_index))
    return
  end

  if phase == 1 then
    -- Stop recording and finalize sample mapping
    song.transport:start_stop_sample_recording()

    local target_inst_index = gbx_record_instrument_index[row_index] or ii

    -- Recording commits the new sample asynchronously, so the slot/audio may not
    -- exist the instant recording stops. Try immediately (covers the rare
    -- synchronous case), and if it's not ready, poll until the recorded sample
    -- actually appears, then finalize once and stop. Bounded to ~6s so a
    -- cancelled/empty recording can never leave a timer running.
    if not PakettiEightOneTwentyFinalizeRecordedSample(row_index, target_inst_index) then
      local attempts = 0
      local poll_fn
      poll_fn = function()
        attempts = attempts + 1
        local done = PakettiEightOneTwentyFinalizeRecordedSample(row_index, target_inst_index)
        -- ~12s budget (was 6s): finalize now also waits for Renoise to rename the
        -- take away from the chassis placeholder name, which lands after the audio.
        if done or attempts >= 120 then
          if renoise.tool():has_timer(poll_fn) then renoise.tool():remove_timer(poll_fn) end
        end
      end
      if renoise.tool():has_timer(poll_fn) then renoise.tool():remove_timer(poll_fn) end
      renoise.tool():add_timer(poll_fn, 100)
    end

    gbx_record_phase[row_index] = 0
    gbx_prev_sample_count[row_index] = 0
    gbx_record_instrument_index[row_index] = 0
    renoise.app():show_status(string.format("8120 Row %02d: Recording stopped. Mapping sample…", row_index))
    return
  end
end

-- Helper to find the primary 00-7F sample for an instrument.
-- A freshly recorded sample can leave the instrument with an empty placeholder
-- still mapped 00-7F, or the recorded slot may not be the one carrying the
-- full-velocity mapping yet. So we don't just grab the first 00-7F slot:
-- 1. a sample that BOTH has audio AND is mapped 00-7F (the ideal primary),
-- 2. else any sample that actually has audio (e.g. the recorded take),
-- 3. else any 00-7F slot (empty placeholder),
-- 4. else slot 1.
-- This keeps the beatsync controls/observers pointed at a real, audible sample
-- instead of silently binding to an empty slot ("clicking does nothing").
function PakettiEightOneTwentyFindPrimarySampleIndex(instrument)
  if not instrument or not instrument.samples or #instrument.samples == 0 then
    return nil
  end
  local first_full_velocity_with_data, first_with_data, first_full_velocity
  for sample_idx, sample in ipairs(instrument.samples) do
    local vr = sample.sample_mapping and sample.sample_mapping.velocity_range
    local is_full = vr and vr[1] == 0x00 and vr[2] == 0x7F
    local buf = sample.sample_buffer
    local has_data = buf and buf.has_sample_data
    if is_full and has_data and not first_full_velocity_with_data then
      first_full_velocity_with_data = sample_idx
    end
    if has_data and not first_with_data then
      first_with_data = sample_idx
    end
    if is_full and not first_full_velocity then
      first_full_velocity = sample_idx
    end
  end
  return first_full_velocity_with_data or first_with_data or first_full_velocity or 1
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
-- track_names, track_indices, instrument_names are forward-declared near the top
-- of this file so functions above this point capture them as upvalues.
track_names = {}  -- Initialize as empty table to avoid nil errors
track_indices = {}  -- Initialize as empty table to avoid nil errors
instrument_names = {}  -- Initialize as empty table to avoid nil errors
local play_checkbox, follow_checkbox, bpm_display, groove_enabled_checkbox, random_gate_button, fill_empty_label, fill_empty_slider, global_step_buttons, global_controls
local local_groove_sliders, local_groove_labels
local number_buttons_row
local number_buttons
local initializing = false  -- Add initializing flag

-- Feature: on opening Groovebox 8120 with an EMPTY song (no real instruments),
-- create the 8 instrument slots and load the Paketti Default Instrument into
-- each, so rows 01-08 are ready to play. Fires ONLY from the 8120 dialog-open
-- path (never on New Song). Guarded by:
--   1. the pakettiEightOneTwentyAutoFillDefaultSlots preference (default ON), and
--   2. an empty-song check (a single, empty instrument) — so it never overwrites
--      an existing song's instruments, and once it fills 8 slots the song is no
--      longer "empty", so reopening 8120 never re-fires.
-- See features/groovebox-8120-default-instrument-slots.feature.
function PakettiEightOneTwentyInitializeDefaultSlots()
  if not (preferences and preferences.pakettiEightOneTwentyAutoFillDefaultSlots
      and preferences.pakettiEightOneTwentyAutoFillDefaultSlots.value) then
    return
  end
  local song = renoise.song()
  if not song then return end
  local function inst_is_empty(inst)
    return inst and #inst.samples == 0
      and not (inst.plugin_properties and inst.plugin_properties.plugin_loaded)
  end
  -- "Empty song" = the fresh-song state: exactly one, empty instrument.
  if not (#song.instruments == 1 and inst_is_empty(song.instruments[1])) then
    return
  end
  if type(pakettiPreferencesDefaultInstrumentLoader) ~= "function" then return end
  renoise.app():show_status("Groovebox 8120: loading Paketti Default Instrument into 8 slots…")
  for i = 1, 8 do
    if #song.instruments < i then
      if not safeInsertInstrumentAt(song, i) then break end
    end
    song.selected_instrument_index = i
    pakettiPreferencesDefaultInstrumentLoader()
  end
  song.selected_instrument_index = 1
end

-- Ensure instruments exist
function ensure_instruments_exist()
  local instrument_count = #renoise.song().instruments
  if instrument_count < 8 then
    for i = instrument_count + 1, 8 do
      if not safeInsertInstrumentAt(renoise.song(), i) then return end
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
        -- Mirror the playhead in the canvas view if it's open.
        if cv_canvas and cv_dialog and cv_dialog.visible then
          cv_canvas:update()
        end
      end
    end
  end
end

-- Global Solo logic: allow multi-solo by muting non-solo rows
gbx_solo_active = false
gbx_prev_mute_states = {}

-- Function to add *Instr. Macros device to a track
function PakettiEightOneTwentyAddInstrMacrosToTrack(track_index)
  local song = renoise.song()
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
    print("  [" .. di .. "] NAME: '" .. (device.name or "nil") .. "' DISPLAY: '" .. (device.display_name or "nil") .. "' PATH: '" .. (device.device_path or "nil") .. "' SHORT: '" .. pakettiSafeDeviceShortName(device) .. "'")
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
  -- Keep the MIDImix step sequencer's focus on whatever row you're interacting
  -- with: HighlightRow is the common entry point for every row-control notifier,
  -- so setting the focused row here makes the 16 MIDImix buttons + LEDs follow
  -- the on-screen row selection. The bridge's idle poller redraws the LEDs for
  -- the new focus within a tick. (Self-contained — no Renoise selected_track tie.)
  if row_index and row_index >= 1 and row_index <= 8 then
    PakettiEightOneTwentyFocusedRow = row_index
  end
  for i, row_elements in ipairs(rows) do
    local rc = row_elements and row_elements.row_container
    if rc then
      -- Available row styles: plain | border | group | panel | body
      if i == row_index then
        pakettiSetViewStyle(rc, "group") -- SELECTED: subtle outline
      else
        pakettiSetViewStyle(rc, "body") -- NOT-SELECTED: light background
      end
    end
      -- Mirror highlight to advanced beatsync/NNA columns
      if beatsync_adv_columns and beatsync_adv_columns[i] then
        if i == row_index then
          pakettiSetViewStyle(beatsync_adv_columns[i], "group")
        else
          pakettiSetViewStyle(beatsync_adv_columns[i], "body")
        end
      end
  end
  -- HighlightRow is the common entry point for nearly every row-control notifier
  -- (and never runs from the playhead timer, which colors buttons directly), so
  -- returning focus here hands keyboard focus back to Renoise after any row
  -- interaction — keeping Shift-V / Shift-A and other global shortcuts working.
  PakettiEightOneTwentyReturnFocus()
end

-- Function to create a row in the UI
function PakettiEightSlotsByOneTwentyCreateRow(row_index)
  local row_elements = {}
  -- Per-cell velocity (used by both classic and canvas views). Indexed by step.
  -- nil = "full velocity, no explicit volume column" (default Renoise behaviour).
  -- 1..127 = explicit volume_value written into the pattern's note column.
  -- The canvas view's cell-drag and double-click set this; the classic view
  -- doesn't expose it directly but reads/writes through it via print_to_pattern.
  row_elements.velocities = {}

  -- Create Instrument Popup first
  local instrument_popup = vb:popup{
    items = instrument_names,
    value = row_index,  -- Set default instrument index to row number
    width=120,
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
      -- Keep Beatsync UI in sync for this row
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
          PakettiEightOneTwentyReturnFocus()
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
    width=18,
    height = 18,
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
      PakettiEightOneTwentyReturnFocus()
    end
  }
    -- Create transpose label
    local transpose_label = vb:text{text="Pitch",font="bold",style="strong",width=36}
    -- Create volume label and rotary
    local volume_label = vb:text{text="Vol",font="bold",style="strong",width=36}
    local volume_rotary = vb:rotary{
      min = -1.0,
      max = 1.0,
      value = (current_volume or 1.0) - 1.0,
      width=18,
      height = 18,
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
        PakettiEightOneTwentyReturnFocus()
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
    steps=pakettiSteps(1, -1),
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
    width = 115,
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
    width = 80,
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
        -- Prevent recursive calls
        if row_elements.updating_checkboxes then 
          print("8120 AUTOMATION DEBUG: *** RECURSIVE CALL BLOCKED ***")
          return 
        end
        row_elements.updating_checkboxes = true
        
        local current_step = i  -- Capture the correct step index
        local current_row = row_index  -- Capture the current row index
        local saved_device, saved_param = nil, nil
        local current_track = renoise.song().selected_track_index
        local target_track = track_indices[row_elements.track_popup.value]
        local current_track_name = renoise.song().tracks[current_track] and renoise.song().tracks[current_track].name or "Unknown"
        local target_track_name = target_track and renoise.song().tracks[target_track] and renoise.song().tracks[target_track].name or "Unknown"
        
        print("8120 AUTOMATION DEBUG: *** BUTTON CLICKED STEP " .. current_step .. " ROW " .. current_row .. " *** STARTING")
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
        

        
        
        -- Get and select the track first
        local track_index = track_indices[row_elements.track_popup.value]
        if track_index then
          local current_before = renoise.song().selected_track_index
          print("8120 AUTOMATION DEBUG: *** ABOUT TO SELECT TRACK " .. track_index .. " (from " .. current_before .. ") *** This will destroy automation selection!")
          
          if track_index == current_before then
            print("8120 AUTOMATION DEBUG: *** NO TRACK CHANGE NEEDED *** Already on target track " .. track_index)
            PakettiEightOneTwentyHighlightRow(row_index)
            -- Don't return here - still need to print to pattern
          else
            -- CAPTURE automation BEFORE track selection destroys it
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
          end
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
        
        -- Always print to pattern regardless of updating_checkboxes flag
        print("8120 AUTOMATION DEBUG: *** CALLING print_to_pattern() ***")
        row_elements.print_to_pattern()
        if track_index then
          PakettiEightOneTwentyRestoreAutomationSelection(saved_device, saved_param, track_index)
        end
        
        -- Always clear the updating flag at the end
        row_elements.updating_checkboxes = false
        PakettiEightOneTwentyReturnFocus()
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
    local instrument_index = row_elements.instrument_popup.value
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
    row_elements.sample_name_label.text = sample_name
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
      steps = pakettiSteps(1, -1),
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
    width=36,
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
    steps = pakettiSteps(1, -1),
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

-- Function to write row to phrase in real-time (for phrase output mode)
function row_elements.write_to_phrase()
  if initializing then return end
  local song = renoise.song()
  if not song then return end
  
  local instrument_index = instrument_popup.value
  local instrument = song.instruments[instrument_index]
  if not instrument then return end
  
  -- Get or create phrase for this row
  local phrase_index = row_index  -- Use row index as phrase index
  
  -- Create phrase if it doesn't exist
  while #instrument.phrases < phrase_index do
    instrument:insert_phrase_at(#instrument.phrases + 1)
  end
  
  local phrase = instrument.phrases[phrase_index]
  if not phrase then return end
  
  local steps = valuebox.value
  
  -- Update phrase properties
  phrase.number_of_lines = steps
  phrase.lpb = song.transport.lpb
  phrase.name = string.format("8120 Row %d", row_index)
  
  -- Check if we need effect column
  local has_yxx = false
  for line = 1, math.min(MAX_STEPS, steps) do
    if row_elements.yxx_checkboxes[line] and row_elements.yxx_checkboxes[line].value then
      has_yxx = true
      break
    end
  end
  if has_yxx then
    phrase.sample_effects_column_visible = true
  end
  
  -- Clear existing phrase content
  for line = 1, phrase.number_of_lines do
    local phrase_line = phrase:line(line)
    phrase_line:note_column(1):clear()
  end
  
  -- Write notes and effects to phrase
  for line = 1, math.min(MAX_STEPS, steps) do
    local note_checkbox_value = row_elements.checkboxes[line] and row_elements.checkboxes[line].value
    local yxx_checkbox_value = row_elements.yxx_checkboxes[line] and row_elements.yxx_checkboxes[line].value
    
    local phrase_line = phrase:line(line)
    local note_col = phrase_line:note_column(1)
    
    if note_checkbox_value then
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = instrument_index - 1
      
      if yxx_checkbox_value and row_elements.yxx_valuebox then
        note_col.effect_number_value = 0x19  -- Y command (sample offset fine)
        note_col.effect_amount_value = row_elements.yxx_valuebox.value
      end
    end
  end
end

-- Function to Print to Pattern (with phrase mode routing)
function row_elements.print_to_pattern()
  if initializing then return end
  
  -- Check output mode and route accordingly
  if PakettiEightOneTwentyOutputMode == "phrase" then
    row_elements.write_to_phrase()
    return
  elseif PakettiEightOneTwentyOutputMode == "phrase_trigger" then
    PakettiEightOneTwentyRowToPhraseTriggersInPattern(row_index, row_index)
    return
  end
  
  -- Original pattern write behavior
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
  local notes_written = 0
  print("8120 PATTERN DEBUG: Starting pattern write for track " .. track_index .. ", steps=" .. steps)
  for line = 1, math.min(MAX_STEPS, steps) do
    local note_checkbox_value = row_elements.checkboxes[line].value
    local yxx_checkbox_value = row_elements.yxx_checkboxes[line].value
    print("8120 PATTERN DEBUG: Line " .. line .. " checkbox=" .. tostring(note_checkbox_value))
    local note_line = track_in_pattern:line(line).note_columns[1]
    local effect_column = track_in_pattern:line(line).effect_columns[1]

    if note_checkbox_value then
      note_line.note_string = "C-4"
      note_line.instrument_value = instrument_index - 1
      -- Per-cell velocity: only set the volume column when explicitly chosen.
      -- nil = leave the volume column empty so Renoise uses default (full).
      local v = row_elements.velocities and row_elements.velocities[line]
      if v then
        if v < 1 then v = 1 end
        if v > 127 then v = 127 end
        note_line.volume_value = v
      end
      notes_written = notes_written + 1
      print("8120 PATTERN DEBUG: Wrote note at line " .. line)

      if yxx_checkbox_value then
        effect_column.number_string = "0Y"
        effect_column.amount_value = row_elements.yxx_valuebox.value
      else
        effect_column:clear()
      end
    end
  end
  print("8120 PATTERN DEBUG: Total notes written: " .. notes_written)

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
    -- Fill the trailing partial block. full_repeats complete blocks cover
    -- full_repeats*steps lines; the remaining lines (e.g. 64 lines / 3 steps =
    -- 21 full blocks + 1 leftover line at the very last row) still belong to the
    -- repeating cycle, so copy as many leading steps of the block as fit.
    local remainder = pattern_length - full_repeats * steps
    if remainder > 0 then
      local start_line = full_repeats * steps + 1
      for line = 1, math.min(remainder, MAX_STEPS) do
        local source_line = track_in_pattern:line(line)
        local dest_line = track_in_pattern:line(start_line + line - 1)
        dest_line.note_columns[1]:copy_from(source_line.note_columns[1])
        dest_line.effect_columns[1]:copy_from(source_line.effect_columns[1])
      end
    end
  end
end

  -- Function to Update Sample Name Label.
  -- Resolves the row's sample through the SAME helper the beatsync controls use
  -- (PakettiEightOneTwentyFindPrimarySampleIndex), so the label and the beatsync
  -- row never disagree about which sample the row represents. The old version
  -- required an exact 00-7F velocity match and showed "No sample available"
  -- whenever a freshly recorded sample didn't have that mapping yet.
  function row_elements.update_sample_name_label()
    local instrument = renoise.song().instruments[row_elements.instrument_popup.value]
    local sample_name = "No sample available"
    if instrument and #instrument.samples > 0 then
      local smp_idx = PakettiEightOneTwentyFindPrimarySampleIndex(instrument)
      local sample = smp_idx and instrument.samples[smp_idx] or nil
      if sample then
        sample_name = sample.name ~= "" and sample.name or string.format("Sample %d", smp_idx)
        -- Truncate sample name if longer than 50 characters
        if #sample_name > 50 then
          sample_name = sample_name:sub(1, 47) .. "..."
        end
      end
    end
    row_elements.sample_name_label.text = sample_name
  end

  -- Function to Initialize Row
  function row_elements.initialize_row()
    local track_index = track_indices[track_popup.value]
    if track_index then
      local track = renoise.song().tracks[track_index]
      -- Get step count from track name when initializing row
      local step_count = getStepsFromTrackName(track.name)
      valuebox.value = step_count
      -- Set selected_step to highlight the step count button
      if step_count == MAX_STEPS then
        row_elements.selected_step = nil
      else
        row_elements.selected_step = step_count
      end
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
      -- Still need to set up automation even when already on correct track
      if saved_device and saved_param then
        print("8120 AUTOMATION DEBUG: *** RESTORING AUTOMATION ON SAME TRACK *** to prevent Volume fallback")
        PakettiEightOneTwentyRestoreAutomationSelection(saved_device, saved_param, track_index)
      else
        print("8120 AUTOMATION DEBUG: *** NO AUTOMATION TO RESTORE ON SAME TRACK *** - will create Pitchbend")
        -- If no previous automation, create Pitchbend on *Instr. Macros device
        PakettiEightOneTwentyRestoreAutomationSelection(nil, nil, track_index)
      end
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
  local eq30_button
  if PAKETTI_HAS_CANVAS then
    eq30_button = vb:button{
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
  else
    eq30_button = vb:space{width=0,height=0}
  end
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

  local hyper_edit_button
  if PAKETTI_HAS_CANVAS then
    hyper_edit_button = vb:button{ text="HyperEdit", notifier=(function(idx)
      return function()
        PakettiEightOneTwentyHighlightRow(row_index)
        local ti = track_indices and row_elements.track_popup and row_elements.track_popup.value and track_indices[row_elements.track_popup.value]
        if ti then renoise.song().selected_track_index = ti end
        local ii = row_elements.instrument_popup and row_elements.instrument_popup.value
        if ii then renoise.song().selected_instrument_index = ii end
        if type(PakettiHyperEditLoadAndShow) == "function" then
          PakettiHyperEditLoadAndShow()
        else
          PakettiHyperEditInit()
        end
      end
    end)(row_index)}
  else
    hyper_edit_button = vb:space{width=0,height=0}
  end

  -- Define the Row Column Layout
  local solo_checkbox = vb:checkbox{value=false,width=36,notifier=function(value)
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

  local mute_label = vb:text{text="Mute",font="bold",style="strong",width=36}
  local solo_label = vb:text{text="Solo",font="bold",style="strong",width=36}

  local labels_row = vb:row{volume_label, vb:space{width=3}, transpose_label}
  -- Knobs stay 25x25 (short, not tall), but each sits in a 36-wide cell (knob +
  -- 11px pad) so the columns line up with the 36-wide Vol/Pitch labels and
  -- Solo/Mute buttons — alignment without a tall knob.
  local rotaries_row = vb:row{
    vb:row{volume_rotary, vb:space{width=18}},
    vb:space{width=3},
    vb:row{transpose_rotary, vb:space{width=18}}
  }
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
      reverse_button, eq30_button, steppers_button, gater_button, record_button, hyper_edit_button,

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
  row_elements.sample_name_label = sample_name_label
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
    PakettiEightOneTwentyReturnFocus()
  end}
  follow_checkbox = vb:checkbox{value = renoise.song().transport.follow_player, notifier=function(value)
    if initializing then return end
    renoise.song().transport.follow_player = value
    PakettiEightOneTwentyReturnFocus()
  end}
  groove_enabled_checkbox = vb:checkbox{value = renoise.song().transport.groove_enabled, notifier=function(value)
    if initializing then return end
    renoise.song().transport.groove_enabled = value
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app().window.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
    PakettiEightOneTwentyReturnFocus()
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
      PakettiEightOneTwentyReturnFocus()
    end}
    groove_controls:add_child(vb:row{local_groove_sliders[i], local_groove_labels[i]})
  end

  random_gate_button = vb:button{ text="Random Gate", midi_mapping="Paketti:Paketti Groovebox 8120:Random Gate", notifier=function()
    if initializing then return end
    random_gate()
    --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
  end}

  fill_empty_label = vb:text{ text="Fill Empty Steps: 0%", style="strong", font="bold",width=140 }
  fill_empty_slider = vb:slider{min = 0, max = 20, value = 0,width=150, steps = pakettiSteps(0.1, -0.1), midi_mapping="Paketti:Paketti Groovebox 8120:Fill Empty Steps Slider", notifier=function(value)
    if initializing then return end
    fill_empty_label.text="Fill Empty Steps: " .. tostring(math.floor(value)) .. "%"
    if value == 0 then
      clear_all()
    else
      fill_empty_steps(value / 100)
      renoise.app():show_status("Filled empty steps with " .. tostring(math.floor(value)) .. "% probability.")
    end
    PakettiEightOneTwentyReturnFocus()
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
    items = {"16", "32"},
    width = 75,
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
          -- Reopen immediately with new settings (monitoring will be handled by the dialog function)
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
      fill_empty_slider,
      vb:text{text=" | ", font = "bold", style = "strong"},
      vb:button{
        text = "MK1->MK2",
        width = 70,
        tooltip = "Open the canvas-rendered MK2 view of the same state. Both windows stay open and edit shared data; close the one you don't want via its X button.",
        notifier = function()
          if PakettiEightOneTwentyCanvasViewShow then
            PakettiEightOneTwentyCanvasViewShow()
          end
        end
      }}}

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
      if not safeInsertInstrumentAt(song, #song.instruments + 1) then return false end
    end

    -- Insert end marker instrument after the first 8 instruments (position 9)
    if not safeInsertInstrumentAt(song, 9) then return false end
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
    vb:button{
      text="Kit",
      tooltip="Pick one base folder; samples are sorted by filename into drum categories — row 1 Kick, 2 Snare, 3 Hihat, 4 Clap, 5 Ride, 6 Perc, 7 Rimshot, 8 Toms/Cymbals/Misc — up to 120 of each.",
      notifier=function()
        loadSequentialKitAll()
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
      midi_mapping = "Paketti:Paketti Groovebox 8120:Global Step " .. (tonumber(step) and string.format("%03d", tonumber(step)) or step),
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
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to reverse all samples
function reverse_all()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  if initializing then 
    -- Restore AutoSamplify monitoring state
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return 
  end
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
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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

  -- Temporarily disable sample monitoring to prevent interference during dialog initialization
  local monitoring_was_enabled = PakettiTemporarilyDisableNewSampleMonitoring()

  initializing = true  -- Set initializing flag to true
  local song = renoise.song()
  local prev_selected_track = song.selected_track_index
  local prev_selected_instrument = song.selected_instrument_index

  PakettiEightOneTwentyInitializeDefaultSlots()  -- Empty-song boot: fill rows 01-08 with the Paketti Default Instrument
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
          if not safeInsertInstrumentAt(song, #song.instruments + 1) then return end
        end
      end
      if not safeInsertInstrumentAt(song, insert_index) then return end
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
  -- Add 'Initialize EQ30' to the top control row (6.2+ only — PakettiEQ30 uses Canvas)
  local init_eq30_button
  if PAKETTI_HAS_CANVAS then
    init_eq30_button = vb:button{
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
  else
    init_eq30_button = vb:space{width=0,height=0}
  end
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
      PakettiEightOneTwentyReturnFocus()
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
      tooltip = string.format("Instrument %02d Beatsync On/Off (set to Off when value is 0)", idx),
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
        -- pcall the writes so that if Renoise ever rejects beat_sync_enabled the
        -- updating flag is still cleared in the finally-style line below — a
        -- thrown write must never wedge the flag true and block all later clicks.
        local ok, err = pcall(function()
          if value then
            local new_lines = beatsync_valueboxes[idx] and beatsync_valueboxes[idx].value or 64
            if new_lines < 1 then new_lines = 1 end
            if new_lines > 512 then new_lines = 512 end
            smp.beat_sync_lines = new_lines
            smp.beat_sync_enabled = true
          else
            smp.beat_sync_enabled = false
          end
        end)
        beatsync_updating[idx] = false
        if not ok then
          renoise.app():show_status("8120 beatsync write rejected: " .. tostring(err))
        end
        PakettiEightOneTwentyReturnFocus()
      end
    }
    local vb_lines = vb:valuebox{
      min = 0,
      max = 512,
      value = 0,
      width = 72,
      tooltip = string.format("Instrument %02d Beatsync Lines (0 = Off)", idx),
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
        PakettiEightOneTwentyReturnFocus()
      end
    }
    beatsync_checkboxes[idx] = cb
    beatsync_valueboxes[idx] = vb_lines
    local col = vb:column{style="body", vb:row{vb:text{text=string.format("%02d", idx), font="bold", style="strong", width=22}, vb_lines, cb}}
    beatsync_adv_columns[idx] = col
    beatsync_row:add_child(col)
  end

  -- Beatsync Mode row (per instrument)
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
        pakettiSafeSetBeatSyncMode(smp, val)
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
          if smp and PAKETTI_HAS_BEAT_SYNC_MODE and smp.beat_sync_mode_observable then
            local function on_mode_change()
              local v = pakettiSafeGetBeatSyncMode(smp) or 1
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

  -- Global Beatsync Mode (auto-applies on change to all)
  local global_mode_popup
  global_mode_popup = vb:popup{
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
              pakettiSafeSetBeatSyncMode(smp, val)
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

  -- Global Beatsync Lines (auto-applies on change to all)
  local global_beatsync_lines_items = {"<None>","16","32","64","128","192","256","512"}
  local global_beatsync_lines_popup
  global_beatsync_lines_popup = vb:popup{
    items = global_beatsync_lines_items,
    width = 80,
    value = 1,  -- Start at "<None>"
    notifier=function()
      local val = global_beatsync_lines_popup.value
      
      -- If "<None>" is selected, don't apply anything
      if val == 1 then
        renoise.app():show_status("Global Beatsync Lines: <None> selected - no changes applied")
        return
      end
      
      -- Convert popup value to actual beatsync lines value
      local beatsync_values = {16, 32, 64, 128, 192, 256, 512}
      local lines_val = beatsync_values[val - 1]
      local total_samples_affected = 0
      
      for i=1,8 do
        local re = rows[i]
        if re then
          local inst_idx = re.instrument_popup and re.instrument_popup.value
          local inst = inst_idx and renoise.song().instruments[inst_idx] or nil
          if inst and inst.samples then
            -- Check if it's a sliced instrument (first sample has slice markers)
            local first_sample = inst.samples[1]
            if first_sample and #first_sample.slice_markers > 0 then
              -- Apply to first sample only for sliced instruments
              first_sample.beat_sync_enabled = true
              first_sample.beat_sync_lines = lines_val
              total_samples_affected = total_samples_affected + 1
            else
              -- Apply to ALL samples in this instrument
              for sample_idx, sample in ipairs(inst.samples) do
                sample.beat_sync_enabled = true
                sample.beat_sync_lines = lines_val
                total_samples_affected = total_samples_affected + 1
              end
            end
          end
        end
      end
      
      renoise.app():show_status(string.format("Global Beatsync Lines: Set %d lines on %d samples across all 8 instruments", lines_val, total_samples_affected))
      
      -- Reset dropdown back to <None> after applying
      global_beatsync_lines_popup.value = 1
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
    vb:row{arrow_button, vb:text{text="Beatsync per Instrument (00-7F sample)", font="bold", style="strong"}},
    vb:column{
      id = beatsync_content_id,
      visible = beatsync_visible,
      beatsync_row,
      beatsync_modes_row,
      
      vb:row{nna_row},
      vb:row{vb:text{text="Global Beatsync", font="bold", style="strong", width=60}, global_mode_popup,       vb:text{text="Global Beatsync Lines", font="bold", style="strong", width=90}, global_beatsync_lines_popup,vb:space{width=8}, vb:text{text="Global NNA", font="bold", style="strong", width=40}, global_nna_popup}

    }
  }
  --dc:add_child(vb:space{height=6})
  dc:add_child(beatsync_container)
  -- Prime Beatsync UI from live song state when foldout starts visible
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
  local keyhandler = function(dialog_obj, key)
    -- Handle Space key to toggle playback
    if key.modifiers == "" and key.name == "space" then
      if play_checkbox then
        play_checkbox.value = not play_checkbox.value
      end
      return nil
    end
    
    -- Handle dialog close key
    local closer = preferences.pakettiDialogClose.value
    if key.modifiers == "" and key.name == closer then
      -- Clean up any observers that might exist
      if cleanup_observers then
        cleanup_observers()
      end
      dialog_obj:close()
      dialog = nil
      return nil
    else
      return key
    end
  end
  dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120", dc, keyhandler)
  
  -- Setup BPM observable after dialog is created
  setup_bpm_observable()
  -- Setup playhead highlight updates after dialog is created
  PakettiEightOneTwentySetupPlayhead()

  -- Re-enable sample monitoring after dialog initialization is complete
  PakettiRestoreNewSampleMonitoring(monitoring_was_enabled)

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
  local release_doc_observer
  -- Shared teardown: detach every observer/timer this dialog attached to the
  -- current song, persist prefs, and unregister the idle watcher + release
  -- observer. Used both when the dialog closes (idle watcher) and right before
  -- the song is released (new song / load). Each removal is guarded, so calling
  -- it twice is safe.
  local function perform_8120_teardown()
    if rows then
      for i = 1, #rows do
        local re = rows[i]
        if re and re.detach_mute_observer then re.detach_mute_observer() end
        if re and re.detach_transpose_observer then re.detach_transpose_observer() end
        if re and re.detach_solo_observer then re.detach_solo_observer() end
        if re and re.detach_volume_observer then re.detach_volume_observer() end
      end
    end
    -- Cleanup playhead observers/timer
    PakettiEightOneTwentyCleanupPlayhead()
    -- Detach beatsync observers
    for i=1,8 do PakettiEightOneTwentyDetachBeatsyncObserversFor(i) end
    -- Clear mode observers
    beatsync_mode_observers = {}
    cleanup_bpm_observable()
    -- Persist preferences explicitly
    if preferences and preferences.save_as then
      preferences:save_as("preferences.xml")
    end
    -- Clear local Beatsync state tables; do not touch vb.views (read-only)
    beatsync_checkboxes = {}
    beatsync_valueboxes = {}
    beatsync_updating = {}
    local s = renoise.song()
    if instruments_list_observer and s and s.instruments_observable:has_notifier(instruments_list_observer) then
      s.instruments_observable:remove_notifier(instruments_list_observer)
    end
    instruments_list_observer = nil
    if dialog_idle_watcher and renoise.tool().app_idle_observable:has_notifier(dialog_idle_watcher) then
      renoise.tool().app_idle_observable:remove_notifier(dialog_idle_watcher)
    end
    dialog_idle_watcher = nil
    if release_doc_observer and renoise.tool().app_release_document_observable:has_notifier(release_doc_observer) then
      renoise.tool().app_release_document_observable:remove_notifier(release_doc_observer)
    end
    release_doc_observer = nil
  end

  dialog_idle_watcher = function()
    if not dialog or (dialog and not dialog.visible) then
      perform_8120_teardown()
    end
  end
  if not renoise.tool().app_idle_observable:has_notifier(dialog_idle_watcher) then
    renoise.tool().app_idle_observable:add_notifier(dialog_idle_watcher)
  end

  -- Tear down BEFORE the song is released (New Song / Load Song). At this point
  -- renoise.song() is still the OLD song, so observers detach cleanly. The 8120
  -- and its canvas are closed too, because their rows/observers/timers and the
  -- canvas's pattern reads are all bound to the song that is about to die —
  -- leaving them live caused a SIGSEGV in Renoise's pattern-pool teardown
  -- (TWeakRefOwner::SOnWeakReferencableDying) when the canvas was open.
  release_doc_observer = function()
    if cv_dialog and cv_dialog.visible then cv_dialog:close() end
    cv_dialog = nil
    cv_canvas = nil
    cv_ui = nil
    if dialog and dialog.visible then dialog:close() end
    dialog = nil
    perform_8120_teardown()
  end
  if not renoise.tool().app_release_document_observable:has_notifier(release_doc_observer) then
    renoise.tool().app_release_document_observable:add_notifier(release_doc_observer)
  end
  -- Restore original selection to avoid unexpected focus changes on open
  if prev_selected_track and prev_selected_track >= 1 and prev_selected_track <= #song.tracks then
    song.selected_track_index = prev_selected_track
  end
  if prev_selected_instrument and prev_selected_instrument >= 1 and prev_selected_instrument <= #song.instruments then
    song.selected_instrument_index = prev_selected_instrument
  end
  -- Auto-open the Akai MidiMix bridge if available (safe to call again
  -- when the dialog is recreated by the 16/32 step toggle, etc.)
  if PakettiEightOneTwentyMidiMixOpen then
    PakettiEightOneTwentyMidiMixOpen()
  end
  -- Auto-detect + arm the APC Key 25 step sequencer (silent if no APC connected).
  if PakettiEightOneTwentyAPCAutoArm then
    PakettiEightOneTwentyAPCAutoArm()
  end
end



-- ============================================================================
-- Headless step access — so the MidiMix step sequencer (step toggles + LEDs)
-- works whether or not the 8120 dialog is open. When the dialog is open, steps
-- live in rows[row].checkboxes (the UI mirror). When it's closed, those don't
-- exist, so we read/write the note directly in the selected pattern: a groovebox
-- row maps to track `row`, instrument `row`, a step is a pattern line, ON = a
-- C-4 note. This is exactly what the dialog's print_to_pattern would produce.
-- ----------------------------------------------------------------------------

-- Is step ON for a row? Dialog checkbox if open, else the selected pattern.
function PakettiEightOneTwentyGetStepState(row, step)
  if dialog and dialog.visible then
    local re = rows and rows[row]
    if re and re.checkboxes and re.checkboxes[step] then
      return re.checkboxes[step].value and true or false
    end
  end
  local song = renoise.song()
  if not song then return false end
  local pattern = song.selected_pattern
  if not pattern or row < 1 or row > #pattern.tracks then return false end
  if step < 1 or step > pattern.number_of_lines then return false end
  local nc = pattern.tracks[row]:line(step).note_columns[1]
  return nc.note_value < 120
end

-- Toggle a step for a row. Dialog open → flip the checkbox (which prints to the
-- pattern). Dialog closed → write the note directly, propagating across every
-- MAX_STEPS-line repeat block so it matches the dialog's repeated output.
function PakettiEightOneTwentyToggleStepState(row, step)
  if dialog and dialog.visible then
    local re = rows and rows[row]
    if re and re.checkboxes and re.checkboxes[step] then
      re.checkboxes[step].value = not re.checkboxes[step].value
      return
    end
  end
  local song = renoise.song()
  if not song then return end
  local pattern = song.selected_pattern
  if not pattern or row < 1 or row > #pattern.tracks then return end
  local plen = pattern.number_of_lines
  if step < 1 or step > MAX_STEPS or step > plen then return end
  local first = pattern.tracks[row]:line(step).note_columns[1]
  local turn_on = (first.note_value >= 120)  -- currently empty → turn on
  local line = step
  while line <= plen do
    local nc = pattern.tracks[row]:line(line).note_columns[1]
    if turn_on then
      nc.note_string = "C-4"
      nc.instrument_value = row - 1
    else
      nc:clear()
    end
    line = line + MAX_STEPS
  end
end

-- Per-step PROBABILITY (Renoise "0Y" Maybe command). Dialog: the row's yxx
-- checkbox. Headless: presence of a "0Y" effect in the step's effect column.
function PakettiEightOneTwentyGetStepYxx(row, step)
  if dialog and dialog.visible then
    local re = rows and rows[row]
    if re and re.yxx_checkboxes and re.yxx_checkboxes[step] then
      return re.yxx_checkboxes[step].value and true or false
    end
  end
  local song = renoise.song()
  if not song then return false end
  local pattern = song.selected_pattern
  if not pattern or row < 1 or row > #pattern.tracks then return false end
  if step < 1 or step > pattern.number_of_lines then return false end
  local ec = pattern.tracks[row]:line(step).effect_columns[1]
  return ec.number_string == "0Y"
end

-- Toggle a step's probability. Dialog open → flip the yxx checkbox. Closed →
-- write/clear the "0Y" effect directly (default amount 0x80 = ~50%, or the row's
-- yxx value when the dialog is open), propagated across MAX_STEPS repeats.
function PakettiEightOneTwentyToggleStepYxx(row, step)
  if dialog and dialog.visible then
    local re = rows and rows[row]
    if re and re.yxx_checkboxes and re.yxx_checkboxes[step] then
      re.yxx_checkboxes[step].value = not re.yxx_checkboxes[step].value
      return
    end
  end
  local song = renoise.song()
  if not song then return end
  local pattern = song.selected_pattern
  if not pattern or row < 1 or row > #pattern.tracks then return end
  local plen = pattern.number_of_lines
  if step < 1 or step > MAX_STEPS or step > plen then return end
  local track = song.tracks[row]
  if track.visible_effect_columns == 0 then track.visible_effect_columns = 1 end
  local first = pattern.tracks[row]:line(step).effect_columns[1]
  local turn_on = (first.number_string ~= "0Y")
  local amount = 0x80
  if dialog and dialog.visible and rows and rows[row] and rows[row].yxx_valuebox then
    amount = rows[row].yxx_valuebox.value
  end
  local line = step
  while line <= plen do
    local ec = pattern.tracks[row]:line(line).effect_columns[1]
    if turn_on then
      ec.number_string = "0Y"
      ec.amount_value = amount
    else
      ec:clear()
    end
    line = line + MAX_STEPS
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
    renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:Global Step " .. (tonumber(step) and string.format("%03d", tonumber(step)) or step),invoke=function(message)
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
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%02d Step%02d", row, step),invoke=function(message)
        if message:is_trigger() then
          PakettiEightOneTwentyToggleStepState(row, step)
        end
      end}
    end
    local buttons = {"<", ">", "Clear", "Randomize", "Load", "Show", "Random", "Automation", "Reverse"}
    for _, btn in ipairs(buttons) do
      renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%02d %s", row, btn),invoke=function(message)
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
    renoise.tool():add_midi_mapping{name=string.format("Paketti:Paketti Groovebox 8120:Row%02d Sample Slider", row),invoke=function(message)
      if not message:is_abs_value() then return end
      -- Tweaking a row's sample slider focuses that row, so the Selected Row Step
      -- buttons (01..16) and the MidiMix LEDs follow the row you're working on.
      PakettiEightOneTwentyFocusedRow = row
      if PakettiEightOneTwentyHighlightRow then PakettiEightOneTwentyHighlightRow(row) end
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

-- =============================================================================
-- Focused-Row MIDI Mappings (controller "page" model)
-- =============================================================================
-- Lets a single bank of 16 physical buttons on a MIDI controller (e.g. EXP1-EXP8
-- + P1-P8) drive the step grid of *whichever* of the 8 rows is currently
-- focused, instead of one bank per row. The focused row is changed with
-- "Focused Row Next/Previous" or "Focused Row Set 1..8" mappings — typically
-- bound to a "page" / "scene" button on the controller.
--
-- Companion mirror mappings exist for the per-row utility buttons (<, >, Clear,
-- Randomize, Load, Show, Random, Automation, Reverse) so the same row-relative
-- workflow extends beyond just the step toggles.
--
-- LED-feedback (lighting the controller's buttons to mirror the focused row's
-- step state) is a follow-up: it requires sending MIDI back out and the SysEx
-- vocabulary differs per controller. Tell me which controller you have and I'll
-- wire that next.

PakettiEightOneTwentyFocusedRow = 1

-- The "selected row" for the MIDImix step sequencer is the groovebox's own
-- focused row (PakettiEightOneTwentyFocusedRow). It is moved by the MIDImix bank
-- buttons, the Focused Row Next/Previous/Set mappings, AND by interacting with a
-- row in the dialog (HighlightRow sets it). It is deliberately NOT tied to
-- Renoise's selected_track_index — the direct-from-input bridge stays
-- self-contained, which is what makes it reliable.
local function paketti_8120_selected_row()
  local f = PakettiEightOneTwentyFocusedRow or 1
  if f < 1 then f = 1 elseif f > 8 then f = 8 end
  return f
end

local function paketti_set_focused_row(target)
  if target < 1 then target = 1 end
  if target > 8 then target = 8 end
  PakettiEightOneTwentyFocusedRow = target
  if PakettiEightOneTwentyHighlightRow then
    PakettiEightOneTwentyHighlightRow(target)
  end
  renoise.app():show_status(string.format("Groovebox 8120: focused row = %d", target))
end

-- Selected Row step toggles — 16 fixed mappings (Step01..Step16) for a 16-button
-- controller bank (e.g. Akai MIDImix). Each toggles that step on WHICHEVER row is
-- selected right now, resolved live, so selecting a different row instantly
-- re-routes all 16 buttons to that row — turning the bank into a step sequencer
-- for the focused track.
for step = 1, 16 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Paketti Groovebox 8120:Selected Row Step%02d", step),
    invoke = function(message)
      if not message:is_trigger() then return end
      if step > MAX_STEPS then return end
      local row = paketti_8120_selected_row()
      PakettiEightOneTwentyToggleStepState(row, step)
    end
  }
end

-- "Disabled NN" — do-nothing placeholder mappings whose ONLY purpose is to ABSORB
-- a controller message. Renoise consumes any MIDI message that is bound to a MIDI
-- mapping, so it never reaches the note-input path. Map each Akai MidiMix step
-- button to one of these (Disabled 01..16) in Renoise's MIDI Map mode and the
-- button stops playing a sample — while the 8120's direct MidiMix bridge still
-- reads the same button independently to toggle the step + light the LED. So you
-- keep the MidiMix as a Renoise MIDI input AND get a clean step sequencer with no
-- note bleed: no need to disable the device.
for i = 1, 16 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Paketti Groovebox 8120:Disabled %02d", i),
    invoke = function(message) end
  }
end

-- Move focus across the 8 rows.
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Focused Row Next [Trigger]",
  invoke = function(message)
    if not message:is_trigger() then return end
    paketti_set_focused_row(paketti_8120_selected_row() % 8 + 1)
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Focused Row Previous [Trigger]",
  invoke = function(message)
    if not message:is_trigger() then return end
    paketti_set_focused_row(((paketti_8120_selected_row() - 2) % 8) + 1)
  end
}

-- Direct row jumps — bind these to dedicated controller buttons if you want to
-- skip a row at a time.
for row = 1, 8 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Paketti Groovebox 8120:Focused Row Set %d [Trigger]", row),
    invoke = function(message)
      if not message:is_trigger() then return end
      paketti_set_focused_row(row)
    end
  }
end

-- Select Row (Knob) — ONE absolute knob/fader (0..127) split evenly across the
-- 8 rows: sweeping it min→max walks the selection through rows 1→8, each setting
-- that row's track AND instrument and focusing it (so the Selected Row Step
-- buttons + MidiMix LEDs follow). 16 values per row (0-15 = row 1 … 112-127 = row 8).
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Select Row (Knob 01-08)",
  invoke = function(message)
    if not message:is_abs_value() then return end
    local v = message.int_value or 0
    local row = math.floor(v / 16) + 1
    if row < 1 then row = 1 elseif row > 8 then row = 8 end
    local song = renoise.song()
    if not song then return end
    if row <= #song.tracks and song:track(row).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      song.selected_track_index = row
    end
    if row <= #song.instruments then
      song.selected_instrument_index = row
    end
    PakettiEightOneTwentyFocusedRow = row
    if PakettiEightOneTwentyHighlightRow then PakettiEightOneTwentyHighlightRow(row) end
    if PakettiEightOneTwentyMidiMixRefreshLedsSilent then PakettiEightOneTwentyMidiMixRefreshLedsSilent() end
    renoise.app():show_status(string.format("Groovebox 8120: knob selected row %02d (track + instrument)", row))
  end
}

-- Select Row (Knob 08-01) — same as above but REVERSED: 0..127 walks rows 8→1.
-- Pick this one for a fader/slider whose travel feels inverted, so pulling it down
-- (or up) moves through the rows in the direction you expect.
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Select Row (Knob 08-01)",
  invoke = function(message)
    if not message:is_abs_value() then return end
    local v = message.int_value or 0
    local row = 8 - math.floor(v / 16)
    if row < 1 then row = 1 elseif row > 8 then row = 8 end
    local song = renoise.song()
    if not song then return end
    if row <= #song.tracks and song:track(row).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      song.selected_track_index = row
    end
    if row <= #song.instruments then
      song.selected_instrument_index = row
    end
    PakettiEightOneTwentyFocusedRow = row
    if PakettiEightOneTwentyHighlightRow then PakettiEightOneTwentyHighlightRow(row) end
    if PakettiEightOneTwentyMidiMixRefreshLedsSilent then PakettiEightOneTwentyMidiMixRefreshLedsSilent() end
    renoise.app():show_status(string.format("Groovebox 8120: slider selected row %02d (track + instrument)", row))
  end
}

-- ============================================================================
-- Master Low-Cut (High-Pass) 200Hz punch toggle
-- ----------------------------------------------------------------------------
-- One toggle: punch it ON to drop everything below ~200Hz off the MASTER track
-- (a high-pass / low-cut at 200Hz), punch it OFF to bring the low end back. The
-- inserted Filter device is tagged by display name so the toggle finds + removes
-- it. The filter type (high-pass) and cutoff (200Hz) are set by READING the
-- parameter's value_string back, so we don't depend on the device's internal
-- value→Hz mapping.
local PAKETTI_MASTER_LOWCUT_TAG = "Paketti LowCut 200Hz"
local PAKETTI_MASTER_LOWCUT_HZ = 200

local function paketti_master_track()
  local song = renoise.song()
  if not song then return nil end
  for i = 1, #song.tracks do
    if song.tracks[i].type == renoise.Track.TRACK_TYPE_MASTER then return song.tracks[i] end
  end
  return nil
end

local function paketti_parse_hz(s)
  if not s then return nil end
  local num = s:match("([%d%.]+)")
  num = num and tonumber(num) or nil
  if not num then return nil end
  if s:lower():find("khz") then num = num * 1000 end
  return num
end

-- The proven Paketti "Hipass (Preset++)" state for the native Digital Filter:
-- Biquad model, Type Value 3 = HIGH PASS. Cutoff starts at min (≈20Hz); we raise
-- it to 200Hz afterwards. (Same XML as HipassPlusPlus in PakettiPresetPlusPlus.lua.)
local PAKETTI_MASTER_HIPASS_XML = [=[<?xml version="1.0" encoding="UTF-8"?>
<FilterDevicePreset doc_version="14">
  <DeviceSlot type="DigitalFilterDevice">
    <IsMaximized>true</IsMaximized>
    <OversamplingFactor>2x</OversamplingFactor>
    <Model>Biquad</Model>
    <Type>
      <Value>3</Value>
    </Type>
    <Cutoff>
      <Value>0.0</Value>
    </Cutoff>
    <Q>
      <Value>0.125</Value>
    </Q>
    <Ripple>
      <Value>0.0</Value>
    </Ripple>
    <Inertia>
      <Value>0.0078125</Value>
    </Inertia>
    <ShowResponseView>true</ShowResponseView>
    <ResponseViewMaxGain>18</ResponseViewMaxGain>
  </DeviceSlot>
</FilterDevicePreset>
]=]

-- Raise the Digital Filter's Cutoff parameter to ~target_hz by reading the
-- displayed value (kHz) back, so it lands on the right frequency regardless of
-- the parameter's internal 0..1 scaling. Returns true on success.
local function paketti_set_cutoff_hz(dev, target_hz)
  for i = 1, #dev.parameters do
    local p = dev.parameters[i]
    if (p.name or ""):lower():find("cutoff") then
      local lo, hi = p.value_min, p.value_max
      local best_v, best_diff
      local function pass(a, b, steps)
        if a < lo then a = lo end
        if b > hi then b = hi end
        for s = 0, steps do
          local v = a + (b - a) * (s / steps)
          p.value = v
          local hz = paketti_parse_hz(p.value_string)
          if hz then
            local d = math.abs(hz - target_hz)
            if (not best_diff) or d < best_diff then best_diff = d best_v = v end
          end
        end
      end
      pass(lo, hi, 200)
      if best_v then
        local span = (hi - lo) / 200
        pass(best_v - span, best_v + span, 100)  -- refine around the best coarse hit
        p.value = best_v
        return true
      end
      return false
    end
  end
  return false
end

-- Find the index of our tagged low-cut device on the master, or nil.
local function paketti_master_lowcut_index(master)
  for i = 1, #master.devices do
    if master.devices[i].display_name == PAKETTI_MASTER_LOWCUT_TAG then return i end
  end
  return nil
end

-- Force the low-cut ON (insert + configure) or OFF (remove). Idempotent: calling
-- it with the state it's already in does nothing, so it's safe for both the
-- toggle and the held/momentary mapping.
function PakettiMasterLowCut200SetState(active)
  local master = paketti_master_track()
  if not master then renoise.app():show_status("Master Low-Cut: no master track found") return end
  local idx = paketti_master_lowcut_index(master)

  if active then
    if idx then return end  -- already on
    local ok, err = pcall(function()
      master:insert_device_at("Audio/Effects/Native/Digital Filter", #master.devices + 1)
    end)
    if not ok then
      renoise.app():show_status("Master Low-Cut: could not insert Digital Filter — " .. tostring(err))
      return
    end
    local dev = master.devices[#master.devices]
    dev.active_preset_data = PAKETTI_MASTER_HIPASS_XML  -- Biquad high-pass (Type 3)
    local set_cut = paketti_set_cutoff_hz(dev, PAKETTI_MASTER_LOWCUT_HZ)
    dev.display_name = PAKETTI_MASTER_LOWCUT_TAG
    dev.is_maximized = false
    if set_cut then
      renoise.app():show_status("Master Low-Cut 200Hz: ON — lows dropped")
    else
      renoise.app():show_status("Master Low-Cut: high-pass added, but could not auto-set 200Hz cutoff — adjust manually")
    end
  else
    if not idx then return end  -- already off
    master:delete_device_at(idx)
    renoise.app():show_status("Master Low-Cut 200Hz: OFF — low end restored")
  end
end

function PakettiToggleMasterLowCut200()
  local master = paketti_master_track()
  if not master then renoise.app():show_status("Master Low-Cut: no master track found") return end
  PakettiMasterLowCut200SetState(paketti_master_lowcut_index(master) == nil)
end

-- Momentary / trigger-and-hold: active WHILE the button is held, off on release.
-- A held button sends press (value > 0 / switch on) then release (value 0 / switch
-- off); we read the message value rather than is_trigger so we catch both edges.
function PakettiMasterLowCut200Momentary(message)
  local on
  if message:is_switch() then
    on = message.boolean_value
  elseif message:is_abs_value() then
    on = (message.int_value or 0) > 0
  elseif message:is_trigger() then
    on = true  -- press-only controller: no release edge available, best effort
  else
    return
  end
  PakettiMasterLowCut200SetState(on)
end

renoise.tool():add_midi_mapping{
  name = "Paketti:Master Low-Cut 200Hz Toggle",
  invoke = function(message) if message:is_trigger() then PakettiToggleMasterLowCut200() end end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Master Low-Cut 200Hz Hold",
  invoke = function(message) PakettiMasterLowCut200Momentary(message) end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Master Low-Cut 200Hz Toggle",
  invoke = function() PakettiToggleMasterLowCut200() end
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Master Low-Cut 200Hz Toggle",
  invoke = function() PakettiToggleMasterLowCut200() end
}

-- Mirror the per-row utility buttons onto the focused row so the same controller
-- bank can drive < / > / Clear / Randomize / Load / Show / Random / Automation /
-- Reverse against whichever row is in focus.
local PAKETTI_FOCUSED_ROW_BUTTONS = {"<", ">", "Clear", "Randomize", "Load", "Show", "Random", "Automation", "Reverse"}
for _, btn in ipairs(PAKETTI_FOCUSED_ROW_BUTTONS) do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Paketti Groovebox 8120:Focused Row %s", btn),
    invoke = function(message)
      if not message:is_trigger() then return end
      local row = paketti_8120_selected_row()
      local row_elements = rows and rows[row]
      if not row_elements then return end
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
      elseif btn == "Randomize" then
        row_elements.randomize()
      elseif btn == "Load" then
        row_elements.browse_instrument()
      elseif btn == "Show" then
        row_elements.select_instrument()
      elseif btn == "Random" then
        row_elements.random_button_pressed()
      elseif btn == "Automation" then
        row_elements.show_automation()
      elseif btn == "Reverse" then
        reverse_sample(row_elements)
      end
    end
  }
end

-- =============================================================================
-- Akai MidiMix bridge — auto-open device, dispatch buttons, drive LEDs
-- =============================================================================
-- Opens the MidiMix as both input and output when the 8120 dialog is shown,
-- closes it when the dialog goes away. The 16 channel buttons (Mute row 1-8 +
-- Rec Arm row 1-8) become focused-row step toggles 1-16. Bank Left/Right walk
-- the focused row through the 8 lanes. LEDs mirror the focused row's step
-- state and redraw on every focus change.
--
-- Factory firmware note layout (channel 1):
--   Mute row    (steps 1-8)  : notes 1, 4, 7, 10, 13, 16, 19, 22
--   Rec Arm row (steps 9-16) : notes 3, 6, 9, 12, 15, 18, 21, 24
--   Bank Left  (focused row -) : note 25
--   Bank Right (focused row +) : note 26
--   Solo                       : note 27 (currently unused; reserved for later)

local PAKETTI_MIDIMIX_MUTE_NOTES   = {1, 4, 7, 10, 13, 16, 19, 22}
local PAKETTI_MIDIMIX_RECARM_NOTES = {3, 6, 9, 12, 15, 18, 21, 24}
local PAKETTI_MIDIMIX_BANK_LEFT  = 25
local PAKETTI_MIDIMIX_BANK_RIGHT = 26

local paketti_midimix_in    = nil
local paketti_midimix_out   = nil
local paketti_midimix_name  = nil
local paketti_midimix_last_led = {}  -- [step] = bool, last value we wrote
local paketti_midimix_idle_attached = false
-- When true, stop auto-opening the bridge: either no MidiMix was detected (don't
-- retry-spam) or the user explicitly closed it. Reset by the explicit toggle.
local paketti_midimix_autoopen_blocked = false

local function paketti_midimix_find_device()
  -- Match common name variants across OSes: "MIDI Mix", "MIDI Mix 1",
  -- "MIDIMIX", "MidiMix", optional bus suffixes.
  local candidates = {
    inputs  = renoise.Midi.available_input_devices()  or {},
    outputs = renoise.Midi.available_output_devices() or {},
  }
  local function match(name)
    local lower = name:lower()
    return lower:find("midi%s*mix") ~= nil
  end
  local in_name, out_name
  for _, n in ipairs(candidates.inputs)  do if match(n) then in_name  = n; break end end
  for _, n in ipairs(candidates.outputs) do if match(n) then out_name = n; break end end
  return in_name, out_name
end

local function paketti_midimix_step_for_note(note)
  for i, n in ipairs(PAKETTI_MIDIMIX_MUTE_NOTES)   do if n == note then return i      end end
  for i, n in ipairs(PAKETTI_MIDIMIX_RECARM_NOTES) do if n == note then return i + 8  end end
  return nil
end

local function paketti_midimix_note_for_step(step)
  if step >= 1 and step <= 8  then return PAKETTI_MIDIMIX_MUTE_NOTES[step]   end
  if step >= 9 and step <= 16 then return PAKETTI_MIDIMIX_RECARM_NOTES[step - 8] end
  return nil
end

local function paketti_midimix_set_led(step, on)
  if not paketti_midimix_out then return end
  local note = paketti_midimix_note_for_step(step)
  if not note then return end
  local velocity = on and 127 or 0
  -- Note On, channel 1
  paketti_midimix_out:send({0x90, note, velocity})
  paketti_midimix_last_led[step] = on
end

local function paketti_midimix_redraw_all_leds()
  if not paketti_midimix_out then return end
  local row = paketti_8120_selected_row()
  for step = 1, 16 do
    paketti_midimix_set_led(step, PakettiEightOneTwentyGetStepState(row, step))
  end
end

-- Silent immediate LED refresh for the row-select knob: pushes the current row's
-- steps to the LEDs without touching the status bar (sweeping the knob must not
-- spam status). Diagnostics go to the TERMINAL via print() so they can be copied.
-- No-op (LED-wise) when the bridge isn't open.
function PakettiEightOneTwentyMidiMixRefreshLedsSilent()
  -- Lazy auto-start (only when the "Auto-Start MidiMix Bridge" setting is ON):
  -- if the bridge isn't open, open it the first time the knob is used so headless
  -- "just works". One attempt only — if no MidiMix is found we set the block flag
  -- so we don't retry (and spam) on every knob move. The explicit toggle clears it.
  if not paketti_midimix_out and not paketti_midimix_autoopen_blocked
     and preferences and preferences.PakettiEightOneTwentyMidiMixAutoStart
     and preferences.PakettiEightOneTwentyMidiMixAutoStart.value then
    local ok = PakettiEightOneTwentyMidiMixOpen()
    if not ok then paketti_midimix_autoopen_blocked = true end
  end
  paketti_midimix_redraw_all_leds()
end

-- Verbose refresh for the explicit "Refresh LEDs" action — reports the bridge
-- state to BOTH the terminal and the status bar (manual press, so no spam).
function PakettiEightOneTwentyMidiMixRefreshLeds()
  if not paketti_midimix_out then
    local msg = "MidiMix LEDs: bridge is NOT open — run 'Groovebox 8120 MidiMix Bridge Toggle' (menu/keybinding) to start it"
    print(msg)
    renoise.app():show_status(msg)
    return false
  end
  paketti_midimix_redraw_all_leds()
  local msg = string.format("MidiMix LEDs refreshed for row %02d (bridge open)", paketti_8120_selected_row())
  print(msg)
  renoise.app():show_status(msg)
  return true
end

local function paketti_midimix_clear_all_leds()
  if not paketti_midimix_out then return end
  for step = 1, 16 do
    paketti_midimix_set_led(step, false)
  end
end

-- Idle poller: cheap diff between checkbox state and last-written LED state.
-- Catches state changes that come from mouse clicks, MIDI mappings other than
-- our own, pattern fetch, randomize, etc. — without us having to instrument
-- every notifier site.
local function paketti_midimix_idle_handler()
  if not paketti_midimix_out then return end
  -- Guard the whole body: a thrown error inside an app_idle notifier makes
  -- Renoise DISABLE the notifier, which would freeze the LEDs (exactly the
  -- "LEDs stay lit but never update" symptom). pcall keeps the poller alive.
  pcall(function()
    local row = paketti_8120_selected_row()

    -- Playhead: while the transport is playing, invert the LED at the current
    -- step so a moving cursor runs across the 16 LEDs. This is the headless
    -- equivalent of the on-screen step highlight (which only runs when the dialog
    -- is open) — the idle poller runs whenever the MidiMix bridge is open.
    local playing_step = nil
    local song = renoise.song()
    if song and song.transport.playing then
      local pos = song.transport.playback_pos
      if pos and pos.line then
        local s = ((pos.line - 1) % MAX_STEPS) + 1
        if s >= 1 and s <= 16 then playing_step = s end
      end
    end

    for step = 1, 16 do
      local led = PakettiEightOneTwentyGetStepState(row, step)
      if playing_step == step then led = not led end  -- highlight the playhead step
      if paketti_midimix_last_led[step] ~= led then
        paketti_midimix_set_led(step, led)
      end
    end
  end)
end

local function paketti_midimix_install_idle()
  if paketti_midimix_idle_attached then return end
  if not renoise.tool().app_idle_observable:has_notifier(paketti_midimix_idle_handler) then
    renoise.tool().app_idle_observable:add_notifier(paketti_midimix_idle_handler)
  end
  paketti_midimix_idle_attached = true
end

local function paketti_midimix_remove_idle()
  if not paketti_midimix_idle_attached then return end
  if renoise.tool().app_idle_observable:has_notifier(paketti_midimix_idle_handler) then
    renoise.tool().app_idle_observable:remove_notifier(paketti_midimix_idle_handler)
  end
  paketti_midimix_idle_attached = false
end

local function paketti_midimix_on_midi(message)
  if type(message) ~= "table" or #message < 3 then return end
  local status, data1, data2 = message[1], message[2], message[3]
  local msg_type = math.floor(status / 16) * 16
  -- Note On with non-zero velocity = press; Note Off OR Note On vel 0 = release
  if msg_type == 0x90 and data2 > 0 then
    if data1 == PAKETTI_MIDIMIX_BANK_LEFT then
      local cur = paketti_8120_selected_row()
      paketti_set_focused_row(((cur - 2) % 8) + 1)
      paketti_midimix_redraw_all_leds()
      return
    end
    if data1 == PAKETTI_MIDIMIX_BANK_RIGHT then
      local cur = paketti_8120_selected_row()
      paketti_set_focused_row(cur % 8 + 1)
      paketti_midimix_redraw_all_leds()
      return
    end
    local step = paketti_midimix_step_for_note(data1)
    if step then
      local row = paketti_8120_selected_row()
      PakettiEightOneTwentyToggleStepState(row, step)
      paketti_midimix_set_led(step, PakettiEightOneTwentyGetStepState(row, step))
    end
  end
end

function PakettiEightOneTwentyMidiMixOpen()
  if paketti_midimix_in then return true end  -- already open
  local in_name, out_name = paketti_midimix_find_device()
  if not in_name and not out_name then
    -- Not found: print the available device names ONCE so a name-match issue is
    -- diagnosable, then bail. No retry loop — we only get here on a deliberate
    -- open attempt (startup, song load, explicit toggle), never in a tight loop.
    print("MIDIMIX OPEN: Akai MidiMix not detected.")
    print("MIDIMIX OPEN: available inputs = " .. table.concat(renoise.Midi.available_input_devices() or {}, " | "))
    print("MIDIMIX OPEN: available outputs = " .. table.concat(renoise.Midi.available_output_devices() or {}, " | "))
    renoise.app():show_status("Groovebox 8120: Akai MidiMix not detected — input/output unchanged")
    return false
  end
  print(string.format("MIDIMIX OPEN: detected in_name=%s out_name=%s", tostring(in_name), tostring(out_name)))
  paketti_midimix_name = in_name or out_name
  if in_name then
    local ok, dev = pcall(renoise.Midi.create_input_device, in_name, paketti_midimix_on_midi)
    if ok and dev then paketti_midimix_in = dev
    else print("Groovebox 8120: failed to open MidiMix input: " .. tostring(dev)) end
  end
  if out_name then
    local ok, dev = pcall(renoise.Midi.create_output_device, out_name)
    if ok and dev then paketti_midimix_out = dev
    else print("Groovebox 8120: failed to open MidiMix output: " .. tostring(dev)) end
  end
  paketti_midimix_last_led = {}
  paketti_midimix_install_idle()
  paketti_midimix_redraw_all_leds()
  renoise.app():show_status("Groovebox 8120: Akai MidiMix opened — buttons drive focused row, LEDs mirror it")
  -- If button presses also PLAY notes, absorb them WITHOUT disabling the device:
  -- in Renoise MIDI Map mode, bind each MidiMix step button to one of the
  -- "Paketti Groovebox 8120:Disabled 01..16" do-nothing mappings. Renoise then
  -- consumes the message (no note bleed) while this bridge still reads the same
  -- button directly to toggle the step + light the LED.
  print("Groovebox 8120 MidiMix: if pressing buttons also plays notes, MIDI-Map each step button to 'Paketti Groovebox 8120:Disabled 01..16' (do-nothing absorbers). That stops the note bleed while the bridge still drives the steps + LEDs — no need to disable the MidiMix as a Renoise input.")
  return true
end

function PakettiEightOneTwentyMidiMixClose()
  paketti_midimix_remove_idle()
  if paketti_midimix_out then
    paketti_midimix_clear_all_leds()
    pcall(function() paketti_midimix_out:close() end)
    paketti_midimix_out = nil
  end
  if paketti_midimix_in then
    pcall(function() paketti_midimix_in:close() end)
    paketti_midimix_in = nil
  end
  paketti_midimix_name = nil
  paketti_midimix_last_led = {}
end

-- Open the bridge if closed, close it if open. This is what you run to START the
-- headless LED work: it opens the MidiMix in/out so the step sequencer LEDs +
-- buttons work with the 8120 dialog closed. Reports what it did + whether the
-- device was found, so it's clear when no MidiMix is detected.
function PakettiEightOneTwentyMidiMixBridgeToggle()
  if paketti_midimix_in or paketti_midimix_out then
    PakettiEightOneTwentyMidiMixClose()
    paketti_midimix_autoopen_blocked = true  -- explicit close: don't auto-reopen
    print("MIDIMIX BRIDGE: CLOSED")
    renoise.app():show_status("Groovebox 8120: MidiMix bridge CLOSED")
  else
    paketti_midimix_autoopen_blocked = false  -- explicit open: allow auto-open again
    local ok = PakettiEightOneTwentyMidiMixOpen()
    local msg = string.format("MIDIMIX BRIDGE: open=%s in=%s out=%s name=%s",
      tostring(ok), tostring(paketti_midimix_in ~= nil), tostring(paketti_midimix_out ~= nil), tostring(paketti_midimix_name))
    print(msg)
    renoise.app():show_status("Groovebox 8120: " .. msg)
  end
end

renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:MidiMix Bridge Toggle [Trigger]",
  invoke = function(message)
    if not message:is_trigger() then return end
    PakettiEightOneTwentyMidiMixBridgeToggle()
  end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 MidiMix Bridge Toggle",
  invoke = function() PakettiEightOneTwentyMidiMixBridgeToggle() end
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:MidiMix Bridge Toggle (start headless LEDs)",
  invoke = function() PakettiEightOneTwentyMidiMixBridgeToggle() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 MidiMix Refresh LEDs",
  invoke = function() PakettiEightOneTwentyMidiMixRefreshLeds() end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:MidiMix Refresh LEDs [Trigger]",
  invoke = function(message) if message:is_trigger() then PakettiEightOneTwentyMidiMixRefreshLeds() end end
}

-- "Auto-Start AKAI MidiMix Bridge" setting. When ON, the bridge opens at startup
-- (and on every song load) so the step LEDs + buttons work without ever opening
-- the 8120 dialog. Persisted in preferences; toggled from a checkable menu entry.
function PakettiEightOneTwentyMidiMixAutoStartEnabled()
  return preferences and preferences.PakettiEightOneTwentyMidiMixAutoStart
    and preferences.PakettiEightOneTwentyMidiMixAutoStart.value or false
end

function PakettiEightOneTwentyToggleMidiMixAutoStart()
  local now = not PakettiEightOneTwentyMidiMixAutoStartEnabled()
  if preferences and preferences.PakettiEightOneTwentyMidiMixAutoStart then
    preferences.PakettiEightOneTwentyMidiMixAutoStart.value = now
    preferences:save_as("preferences.xml")
  end
  if now then
    -- Turning it ON: open the bridge right away (don't make the user wait for a
    -- restart) and clear the auto-open block.
    paketti_midimix_autoopen_blocked = false
    PakettiEightOneTwentyMidiMixOpen()
    renoise.app():show_status("Auto-Start AKAI MidiMix Bridge: ON — bridge opened")
  else
    renoise.app():show_status("Auto-Start AKAI MidiMix Bridge: OFF (bridge left as-is)")
  end
end

PakettiAddMenuEntry{
  name = "Main Menu:Options:Auto-Start AKAI MidiMix Bridge",
  selected = function() return PakettiEightOneTwentyMidiMixAutoStartEnabled() end,
  invoke = function() PakettiEightOneTwentyToggleMidiMixAutoStart() end
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Auto-Start AKAI MidiMix Bridge",
  selected = function() return PakettiEightOneTwentyMidiMixAutoStartEnabled() end,
  invoke = function() PakettiEightOneTwentyToggleMidiMixAutoStart() end
}

-- Startup auto-start: when the setting is ON, open the bridge once a document is
-- available. app_new_document fires at launch and on every song load; MidiMixOpen
-- is idempotent (early-returns if already open), so this just ensures it's up.
local function paketti_midimix_autostart_on_doc()
  if PakettiEightOneTwentyMidiMixAutoStartEnabled() and not paketti_midimix_in then
    paketti_midimix_autoopen_blocked = false
    PakettiEightOneTwentyMidiMixOpen()
  end
end
if not renoise.tool().app_new_document_observable:has_notifier(paketti_midimix_autostart_on_doc) then
  renoise.tool().app_new_document_observable:add_notifier(paketti_midimix_autostart_on_doc)
end
-- And open it once now: at launch the tool loads AFTER the song, so the
-- app_new_document above already fired before our notifier was attached. A short
-- deferred timer lets MIDI/devices settle first.
if PakettiEightOneTwentyMidiMixAutoStartEnabled() then
  local paketti_midimix_autostart_timer
  paketti_midimix_autostart_timer = function()
    renoise.tool():remove_timer(paketti_midimix_autostart_timer)
    paketti_midimix_autostart_on_doc()
  end
  renoise.tool():add_timer(paketti_midimix_autostart_timer, 800)
end

-- ============================================================================
-- AKAI APC Key 25 — step-sequencer PROBE (proof of concept)
-- ----------------------------------------------------------------------------
-- The APC Key 25 has an 8x5 = 40 pad grid with colour LEDs (far more than the
-- MidiMix's 16). The bridge architecture generalises directly, but the exact pad
-- note-numbers and the LED colour map differ between mk1 (red/green/yellow, set
-- by velocity) and mk2 (RGB) and must NOT be guessed. This probe proves the two
-- things we need and gathers the real data: (1) we can READ the pads — open it
-- and every press prints "APC IN: …" to the terminal; (2) we can LIGHT them —
-- the LED test walks notes 0..39 with cycling velocities so we see the palette.
local paketti_apc_in  = nil
local paketti_apc_out = nil

local function paketti_apc_find_device()
  local function match(name) return name:lower():find("apc") ~= nil end
  local in_name, out_name
  for _, n in ipairs(renoise.Midi.available_input_devices()  or {}) do if match(n) then in_name  = n break end end
  for _, n in ipairs(renoise.Midi.available_output_devices() or {}) do if match(n) then out_name = n break end end
  return in_name, out_name
end

local function paketti_apc_on_midi(message)
  if type(message) ~= "table" or #message < 3 then return end
  local status, d1, d2 = message[1], message[2], message[3]
  print(string.format("APC IN: status=0x%02X type=0x%02X ch=%d data1=%d data2=%d",
    status, math.floor(status / 16) * 16, (status % 16) + 1, d1, d2))
end

function PakettiEightOneTwentyAPCProbeOpen()
  if paketti_apc_in then renoise.app():show_status("APC probe already open") return end
  local in_name, out_name = paketti_apc_find_device()
  print("APC PROBE: in_name=" .. tostring(in_name) .. " out_name=" .. tostring(out_name))
  print("APC PROBE: available inputs = " .. table.concat(renoise.Midi.available_input_devices() or {}, " | "))
  print("APC PROBE: available outputs = " .. table.concat(renoise.Midi.available_output_devices() or {}, " | "))
  if not in_name then
    renoise.app():show_status("APC: no MIDI device with 'APC' in the name — see terminal for the device list")
    return
  end
  local ok, dev = pcall(renoise.Midi.create_input_device, in_name, paketti_apc_on_midi)
  if ok and dev then paketti_apc_in = dev else print("APC: input open failed: " .. tostring(dev)) end
  if out_name then
    local ok2, dev2 = pcall(renoise.Midi.create_output_device, out_name)
    if ok2 and dev2 then paketti_apc_out = dev2 else print("APC: output open failed: " .. tostring(dev2)) end
  end
  renoise.app():show_status("APC probe OPEN — press pads/keys; watch the terminal for 'APC IN:' lines")
end

function PakettiEightOneTwentyAPCProbeClose()
  -- Stop any running animation and turn EVERY pad off (incl. the blink velocities)
  -- BEFORE closing the output — otherwise the hardware keeps flashing forever.
  if PakettiEightOneTwentyAPCStop then PakettiEightOneTwentyAPCStop() end
  if paketti_apc_out then
    for n = 0, 39 do pcall(function() paketti_apc_out:send({0x90, n, 0}) end) end
  end
  if paketti_apc_in  then pcall(function() paketti_apc_in:close()  end) paketti_apc_in  = nil end
  if paketti_apc_out then pcall(function() paketti_apc_out:close() end) paketti_apc_out = nil end
  renoise.app():show_status("APC probe closed (LEDs cleared)")
end

-- Send Note On to pads 0..39 with cycling velocities 1..6 so we can see which
-- velocity makes which colour (mk1 palette: 1 green, 3 red, 5 yellow + blinks).
function PakettiEightOneTwentyAPCTestLeds()
  if not paketti_apc_out then
    renoise.app():show_status("APC: output not open — run 'APC Probe Open' first")
    return
  end
  for note = 0, 39 do
    paketti_apc_out:send({0x90, note, (note % 6) + 1})
  end
  print("APC TEST: sent Note On (0x90) to pads 0..39 with velocities 1..6 — note which pads light and what colour.")
  renoise.app():show_status("APC: sent test colours to pads 0..39 — tell me what lights up")
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Probe Open",  invoke=function() PakettiEightOneTwentyAPCProbeOpen() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Probe Close", invoke=function() PakettiEightOneTwentyAPCProbeClose() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Test LEDs",   invoke=function() PakettiEightOneTwentyAPCTestLeds() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Probe — Open (read pads to terminal)", invoke=function() PakettiEightOneTwentyAPCProbeOpen() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Probe — Test pad LEDs",              invoke=function() PakettiEightOneTwentyAPCTestLeds() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Probe — Close",                      invoke=function() PakettiEightOneTwentyAPCProbeClose() end}

-- ============================================================================
-- AKAI APC Key 25 mk1 — interactive light-show demo (confirmed by the probe)
-- ----------------------------------------------------------------------------
-- CONFIRMED FROM THE PROBE (APC Key 25 mk1):
--   * Pads send Note On/Off on channel 1. note = row*8 + col, note 0 = BOTTOM-
--     LEFT, col 0 = left. Bottom row = notes 0..7, top row = notes 32..39.
--   * Pad LED = Note On ch1 with velocity: 0 off, 1 green, 2 green-blink,
--     3 red, 4 red-blink, 5 yellow, 6 yellow-blink.
-- This demo: press any pad to cycle its colour (off->green->red->yellow), plus an
-- intro sweep animation across all 40 pads. Proves real-time read + per-pad write,
-- which is everything the real step sequencer needs.
local APC_OFF, APC_GREEN, APC_RED, APC_YELLOW = 0, 1, 3, 5
local apc_pad_state = {}        -- [note] = 0 off / 1 green / 2 red / 3 yellow
local APC_CYCLE_VEL = {[0]=APC_OFF, [1]=APC_GREEN, [2]=APC_RED, [3]=APC_YELLOW}
local APC_CYCLE_NAME = {[0]="off", [1]="green", [2]="red", [3]="yellow"}
local apc_show_timer_fn = nil
local apc_show_frame = 0

local function paketti_apc_set_pad(note, vel)
  if not paketti_apc_out then return end
  if note < 0 or note > 39 then return end
  paketti_apc_out:send({0x90, note, vel})
end

local function paketti_apc_clear_all()
  for n = 0, 39 do paketti_apc_set_pad(n, APC_OFF) end
end

-- Interactive: every pad press advances that pad's colour and lights it.
local function paketti_apc_demo_on_midi(message)
  if type(message) ~= "table" or #message < 3 then return end
  local status, d1, d2 = message[1], message[2], message[3]
  if math.floor(status / 16) * 16 == 0x90 and d2 > 0 and d1 >= 0 and d1 <= 39 then
    local s = ((apc_pad_state[d1] or 0) + 1) % 4
    apc_pad_state[d1] = s
    paketti_apc_set_pad(d1, APC_CYCLE_VEL[s])
    print(string.format("APC PAD note=%d (row %d, col %d) -> %s", d1, math.floor(d1 / 8), d1 % 8, APC_CYCLE_NAME[s]))
  end
end

local function paketti_apc_show_step()
  local f = apc_show_frame
  if f <= 7 then
    -- Paint column f top-to-bottom, colour cycling green/red/yellow per column.
    local vel = ({APC_GREEN, APC_RED, APC_YELLOW})[(f % 3) + 1]
    for row = 0, 4 do paketti_apc_set_pad(row * 8 + f, vel) end
  elseif f <= 15 then
    -- Clear columns left to right, leaving the grid blank.
    local c = f - 8
    for row = 0, 4 do paketti_apc_set_pad(row * 8 + c, APC_OFF) end
  else
    if apc_show_timer_fn and renoise.tool():has_timer(apc_show_timer_fn) then
      renoise.tool():remove_timer(apc_show_timer_fn)
    end
    apc_show_timer_fn = nil
    paketti_apc_clear_all()
    return
  end
  apc_show_frame = f + 1
end

function PakettiEightOneTwentyAPCLightShow()
  if not paketti_apc_out then
    renoise.app():show_status("APC: output not open — run 'APC Demo — Open' first")
    return
  end
  apc_show_frame = 0
  if not apc_show_timer_fn then
    apc_show_timer_fn = function() paketti_apc_show_step() end
    renoise.tool():add_timer(apc_show_timer_fn, 90)
  end
end

-- Open the APC for the interactive demo (closes the plain probe callback first so
-- presses cycle colours instead of just printing), clear the grid, intro sweep.
function PakettiEightOneTwentyAPCDemoOpen()
  PakettiEightOneTwentyAPCProbeClose()  -- drop any existing handles/callback
  local in_name, out_name = paketti_apc_find_device()
  if not in_name and not out_name then
    renoise.app():show_status("APC: not detected — see terminal device list")
    return
  end
  if in_name then
    local ok, dev = pcall(renoise.Midi.create_input_device, in_name, paketti_apc_demo_on_midi)
    if ok and dev then paketti_apc_in = dev else print("APC demo: input open failed: " .. tostring(dev)) end
  end
  if out_name then
    local ok, dev = pcall(renoise.Midi.create_output_device, out_name)
    if ok and dev then paketti_apc_out = dev else print("APC demo: output open failed: " .. tostring(dev)) end
  end
  apc_pad_state = {}
  paketti_apc_clear_all()
  PakettiEightOneTwentyAPCLightShow()
  renoise.app():show_status("APC Demo OPEN — press pads to cycle colours (off/green/red/yellow)")
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Demo Open",      invoke=function() PakettiEightOneTwentyAPCDemoOpen() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Light Show",     invoke=function() PakettiEightOneTwentyAPCLightShow() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Demo — Open (press pads to paint)", invoke=function() PakettiEightOneTwentyAPCDemoOpen() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Demo — Light Show",                 invoke=function() PakettiEightOneTwentyAPCLightShow() end}

-- ============================================================================
-- APC Key 25 — proper light art (scrolling text, fireworks, lightning)
-- ----------------------------------------------------------------------------
-- A small animation engine over the 8x5 grid. A frame buffer holds a colour per
-- pad (note 0..39); a diff renderer sends only changed pads (so it's smooth, not
-- a MIDI flood). xy helper: col 0..7, top_row 0..4 with row 0 = TOP so text reads
-- the right way up. Every animation is a step(frame, buf) that fills the buffer.
local paketti_apc_prev = {}        -- [note] = last velocity sent (diff state)
local paketti_apc_anim_fn = nil
local paketti_apc_anim_frame = 0

local function paketti_apc_xy_note(col, top_row) return (4 - top_row) * 8 + col end

local function paketti_apc_render(buf)
  for n = 0, 39 do
    local v = buf[n] or APC_OFF
    if paketti_apc_prev[n] ~= v then
      paketti_apc_set_pad(n, v)
      paketti_apc_prev[n] = v
    end
  end
end

-- Stop EVERYTHING: kill any animation timer (and the old column-sweep timer),
-- turn every pad off (clears the blink velocities too), reset the diff state.
function PakettiEightOneTwentyAPCStop()
  if paketti_apc_anim_fn and renoise.tool():has_timer(paketti_apc_anim_fn) then
    renoise.tool():remove_timer(paketti_apc_anim_fn)
  end
  paketti_apc_anim_fn = nil
  if apc_show_timer_fn and renoise.tool():has_timer(apc_show_timer_fn) then
    renoise.tool():remove_timer(apc_show_timer_fn)
  end
  apc_show_timer_fn = nil
  if paketti_apc_out then for n = 0, 39 do paketti_apc_set_pad(n, APC_OFF) end end
  paketti_apc_prev = {}
  renoise.app():show_status("APC: stopped — all LEDs off")
end

local function paketti_apc_run_anim(step_fn, interval)
  PakettiEightOneTwentyAPCStop()
  if not paketti_apc_out then
    renoise.app():show_status("APC: output not open — run 'APC Demo — Open' first")
    return false
  end
  paketti_apc_prev = {}  -- force a full redraw on the first frame
  paketti_apc_anim_frame = 0
  paketti_apc_anim_fn = function()
    local f = paketti_apc_anim_frame
    paketti_apc_anim_frame = f + 1
    local buf = {}
    local cont = step_fn(f, buf)
    paketti_apc_render(buf)
    if cont == false then PakettiEightOneTwentyAPCStop() end
  end
  renoise.tool():add_timer(paketti_apc_anim_fn, interval or 90)
  return true
end

-- 5-row x 3-col font (X = lit). Enough to read while scrolling.
local APC_FONT = {
  [" "]={"...","...","...","...","..."},  ["-"]={"...","...","XXX","...","..."},
  ["A"]={".X.","X.X","XXX","X.X","X.X"},  ["B"]={"XX.","X.X","XX.","X.X","XX."},
  ["C"]={".XX","X..","X..","X..",".XX"},  ["D"]={"XX.","X.X","X.X","X.X","XX."},
  ["E"]={"XXX","X..","XX.","X..","XXX"},  ["F"]={"XXX","X..","XX.","X..","X.."},
  ["G"]={".XX","X..","X.X","X.X",".XX"},  ["H"]={"X.X","X.X","XXX","X.X","X.X"},
  ["I"]={"XXX",".X.",".X.",".X.","XXX"},  ["J"]={"..X","..X","..X","X.X",".X."},
  ["K"]={"X.X","XX.","X..","XX.","X.X"},  ["L"]={"X..","X..","X..","X..","XXX"},
  ["M"]={"X.X","XXX","XXX","X.X","X.X"},  ["N"]={"X.X","XX.","X.X","X.X","X.X"},
  ["O"]={".X.","X.X","X.X","X.X",".X."},  ["P"]={"XX.","X.X","XX.","X..","X.."},
  ["Q"]={".X.","X.X","X.X","XX.",".XX"},  ["R"]={"XX.","X.X","XX.","XX.","X.X"},
  ["S"]={".XX","X..",".X.","..X","XX."},  ["T"]={"XXX",".X.",".X.",".X.",".X."},
  ["U"]={"X.X","X.X","X.X","X.X",".X."},  ["V"]={"X.X","X.X","X.X",".X.",".X."},
  ["W"]={"X.X","X.X","XXX","XXX","X.X"},  ["X"]={"X.X","X.X",".X.","X.X","X.X"},
  ["Y"]={"X.X","X.X",".X.",".X.",".X."},  ["Z"]={"XXX","..X",".X.","X..","XXX"},
  ["0"]={".X.","X.X","X.X","X.X",".X."},  ["1"]={".X.","XX.",".X.",".X.","XXX"},
  ["2"]={"XX.","..X",".X.","X..","XXX"},  ["3"]={"XX.","..X",".X.","..X","XX."},
  ["4"]={"X.X","X.X","XXX","..X","..X"},  ["5"]={"XXX","X..","XX.","..X","XX."},
  ["6"]={".XX","X..","XX.","X.X",".X."},  ["7"]={"XXX","..X",".X.",".X.",".X."},
  ["8"]={".X.","X.X",".X.","X.X",".X."},  ["9"]={".X.","X.X",".XX","..X","XX."},
}
local paketti_apc_text_msg = "PAKETTI SUPPORTS APC KEY 25 - STAY TUNED FOR PAKETTI GROOVEBOX 8120   "
local paketti_apc_text_cols = nil

local function paketti_apc_build_text()
  local cols = {}
  local m = paketti_apc_text_msg
  for i = 1, #m do
    local g = APC_FONT[m:sub(i, i):upper()] or APC_FONT[" "]
    for c = 1, 3 do
      local bits = {}
      for r = 1, 5 do bits[r] = (g[r]:sub(c, c) == "X") end
      cols[#cols + 1] = bits
    end
    cols[#cols + 1] = {false, false, false, false, false}  -- 1-col gap between glyphs
  end
  return cols
end

local function paketti_apc_scroll_step(frame, buf)
  if not paketti_apc_text_cols then paketti_apc_text_cols = paketti_apc_build_text() end
  local total = #paketti_apc_text_cols
  local offset = (frame % (total + 8)) - 7   -- enters from the right, loops forever
  local vel = ({APC_GREEN, APC_YELLOW, APC_RED})[(math.floor(frame / 30) % 3) + 1]
  for dc = 0, 7 do
    local src = offset + dc
    if src >= 0 and src < total then
      local bits = paketti_apc_text_cols[src + 1]
      for r = 0, 4 do if bits[r + 1] then buf[paketti_apc_xy_note(dc, r)] = vel end end
    end
  end
  return true
end

local paketti_apc_fw = {}
local function paketti_apc_fireworks_step(frame, buf)
  if frame % 6 == 0 then
    paketti_apc_fw[#paketti_apc_fw + 1] = {col = math.random(0, 7), row = math.random(0, 4),
      age = 0, vel = ({APC_GREEN, APC_RED, APC_YELLOW})[math.random(1, 3)]}
  end
  local keep = {}
  for _, b in ipairs(paketti_apc_fw) do
    if b.age == 0 then
      buf[paketti_apc_xy_note(b.col, b.row)] = b.vel
    else
      for dr = -b.age, b.age do                 -- expanding diamond ring
        local dc = b.age - math.abs(dr)
        local r = b.row + dr
        if r >= 0 and r <= 4 then
          if b.col + dc >= 0 and b.col + dc <= 7 then buf[paketti_apc_xy_note(b.col + dc, r)] = b.vel end
          if b.col - dc >= 0 and b.col - dc <= 7 then buf[paketti_apc_xy_note(b.col - dc, r)] = b.vel end
        end
      end
    end
    b.age = b.age + 1
    if b.age <= 4 then keep[#keep + 1] = b end
  end
  paketti_apc_fw = keep
  return true
end

local paketti_apc_bolt = nil
local function paketti_apc_lightning_step(frame, buf)
  local phase = frame % 10
  if phase == 0 then                            -- new zigzag bolt top->bottom
    paketti_apc_bolt = {}
    local c = math.random(0, 7)
    for r = 0, 4 do
      paketti_apc_bolt[r] = c
      c = c + math.random(-1, 1)
      if c < 0 then c = 0 elseif c > 7 then c = 7 end
    end
  end
  if paketti_apc_bolt and phase <= 2 then        -- flash it for a few frames
    for r = 0, 4 do buf[paketti_apc_xy_note(paketti_apc_bolt[r], r)] = APC_YELLOW end
  end
  return true
end

-- Ensure the device is open (output needed for LEDs) without the press-to-cycle
-- intro; opens read+write so pads still register if you want.
local function paketti_apc_ensure_open()
  if paketti_apc_out then return true end
  PakettiEightOneTwentyAPCDemoOpen()
  return paketti_apc_out ~= nil
end

function PakettiEightOneTwentyAPCScrollText()
  if not paketti_apc_ensure_open() then return end
  paketti_apc_text_cols = nil
  paketti_apc_run_anim(paketti_apc_scroll_step, 90)
  renoise.app():show_status("APC: scrolling text — use 'APC — Stop' to clear")
end
function PakettiEightOneTwentyAPCFireworks()
  if not paketti_apc_ensure_open() then return end
  paketti_apc_fw = {}
  paketti_apc_run_anim(paketti_apc_fireworks_step, 110)
  renoise.app():show_status("APC: fireworks — use 'APC — Stop' to clear")
end
function PakettiEightOneTwentyAPCLightning()
  if not paketti_apc_ensure_open() then return end
  paketti_apc_run_anim(paketti_apc_lightning_step, 80)
  renoise.app():show_status("APC: lightning — use 'APC — Stop' to clear")
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Scroll Text", invoke=function() PakettiEightOneTwentyAPCScrollText() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Fireworks",   invoke=function() PakettiEightOneTwentyAPCFireworks() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Lightning",   invoke=function() PakettiEightOneTwentyAPCLightning() end}
renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Stop",        invoke=function() PakettiEightOneTwentyAPCStop() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC — Scroll Text", invoke=function() PakettiEightOneTwentyAPCScrollText() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC — Fireworks",   invoke=function() PakettiEightOneTwentyAPCFireworks() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC — Lightning",   invoke=function() PakettiEightOneTwentyAPCLightning() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC — Stop (clear all LEDs)", invoke=function() PakettiEightOneTwentyAPCStop() end}

-- ============================================================================
-- APC Key 25 — Groovebox 8120 STEP SEQUENCER bridge
-- ----------------------------------------------------------------------------
-- The 8x5 grid drives the SELECTED 8120 row:
--   16-step mode: top 2 rows = steps 1..16, next 2 rows = per-step probability
--                 (the 0Y "Maybe" command), bottom row = select instrument/row.
--   32-step mode: top 4 rows = steps 1..32, bottom row = select instrument/row.
-- LEDs: step on = green, playhead = yellow; probability on = red; selected row =
-- green, the other 7 selectors = red. Pad note = row*8+col, row 0 = bottom, so
-- top_row = 4 - (note/8). Works headless via the same Get/Toggle helpers; a timer
-- redraws so the playhead moves. Start/stop from menu, keybinding or MIDI.
local paketti_apc_seq_active = false
local paketti_apc_seq_timer_fn = nil

local function paketti_apc_seq_zone(note)
  local top = 4 - math.floor(note / 8)   -- 0 = top row, 4 = bottom row
  local col = note % 8
  if top == 4 then return "select", col + 1 end           -- bottom row: rows 1..8
  if MAX_STEPS >= 32 then
    return "step", top * 8 + col + 1                       -- top 4 rows: steps 1..32
  end
  if top <= 1 then return "step", top * 8 + col + 1 end    -- rows 0-1: steps 1..16
  return "prob", (top - 2) * 8 + col + 1                   -- rows 2-3: probability 1..16
end

local function paketti_apc_seq_refresh()
  if not (paketti_apc_seq_active and paketti_apc_out) then return end
  local row = paketti_8120_selected_row()
  local playing_step = nil
  local song = renoise.song()
  if song and song.transport.playing then
    local pos = song.transport.playback_pos
    if pos and pos.line then playing_step = ((pos.line - 1) % MAX_STEPS) + 1 end
  end
  local buf = {}
  for note = 0, 39 do
    local zone, idx = paketti_apc_seq_zone(note)
    local vel = APC_OFF
    if zone == "step" then
      if idx <= MAX_STEPS then
        if PakettiEightOneTwentyGetStepState(row, idx) then vel = APC_GREEN end
        if playing_step == idx then vel = APC_YELLOW end
      end
    elseif zone == "prob" then
      if idx <= MAX_STEPS and PakettiEightOneTwentyGetStepYxx(row, idx) then vel = APC_RED end
    elseif zone == "select" then
      vel = (idx == row) and APC_GREEN or APC_RED
    end
    buf[note] = vel
  end
  paketti_apc_render(buf)
end

local function paketti_apc_seq_on_midi(message)
  if not paketti_apc_seq_active then return end
  if type(message) ~= "table" or #message < 3 then return end
  local status, d1, d2 = message[1], message[2], message[3]
  if math.floor(status / 16) * 16 ~= 0x90 or d2 <= 0 or d1 < 0 or d1 > 39 then return end
  local zone, idx = paketti_apc_seq_zone(d1)
  local row = paketti_8120_selected_row()
  if zone == "step" then
    if idx <= MAX_STEPS then PakettiEightOneTwentyToggleStepState(row, idx) end
  elseif zone == "prob" then
    if idx <= MAX_STEPS then PakettiEightOneTwentyToggleStepYxx(row, idx) end
  elseif zone == "select" then
    if idx >= 1 and idx <= 8 then
      PakettiEightOneTwentyFocusedRow = idx
      local song = renoise.song()
      if song then
        if idx <= #song.tracks and song:track(idx).type == renoise.Track.TRACK_TYPE_SEQUENCER then song.selected_track_index = idx end
        if idx <= #song.instruments then song.selected_instrument_index = idx end
      end
      if PakettiEightOneTwentyHighlightRow then PakettiEightOneTwentyHighlightRow(idx) end
    end
  end
  paketti_apc_seq_refresh()
end

function PakettiEightOneTwentyAPCSeqStop()
  paketti_apc_seq_active = false
  if paketti_apc_seq_timer_fn and renoise.tool():has_timer(paketti_apc_seq_timer_fn) then
    renoise.tool():remove_timer(paketti_apc_seq_timer_fn)
  end
  paketti_apc_seq_timer_fn = nil
  if PakettiEightOneTwentyAPCStop then PakettiEightOneTwentyAPCStop() end  -- clears LEDs
  renoise.app():show_status("APC 8120 step sequencer: OFF")
end

function PakettiEightOneTwentyAPCSeqStart()
  -- Already armed and the device is open? Don't churn (close+reopen the MIDI
  -- device) — this is called on every 8120 dialog open and 16/32 toggle. Just
  -- repaint and bail.
  if paketti_apc_seq_active and paketti_apc_in then
    paketti_apc_seq_refresh()
    return
  end
  if PakettiEightOneTwentyAPCStop then PakettiEightOneTwentyAPCStop() end  -- stop animations/clear
  -- (Re)open the device with the SEQUENCER callback so pads drive the 8120.
  PakettiEightOneTwentyAPCProbeClose()
  local in_name, out_name = paketti_apc_find_device()
  if not in_name and not out_name then
    renoise.app():show_status("APC: not detected — see terminal device list")
    return
  end
  if in_name then
    local ok, dev = pcall(renoise.Midi.create_input_device, in_name, paketti_apc_seq_on_midi)
    if ok and dev then paketti_apc_in = dev else print("APC seq: input open failed: " .. tostring(dev)) end
  end
  if out_name then
    local ok, dev = pcall(renoise.Midi.create_output_device, out_name)
    if ok and dev then paketti_apc_out = dev else print("APC seq: output open failed: " .. tostring(dev)) end
  end
  paketti_apc_seq_active = true
  paketti_apc_prev = {}
  if not paketti_apc_seq_timer_fn then
    paketti_apc_seq_timer_fn = function() paketti_apc_seq_refresh() end
    renoise.tool():add_timer(paketti_apc_seq_timer_fn, 50)
  end
  paketti_apc_seq_refresh()
  renoise.app():show_status("APC 8120 step sequencer: ON — top rows = steps, mid rows = probability, bottom row = select row")
end

function PakettiEightOneTwentyAPCSeqToggle()
  if paketti_apc_seq_active then PakettiEightOneTwentyAPCSeqStop() else PakettiEightOneTwentyAPCSeqStart() end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120 APC Step Sequencer Toggle", invoke=function() PakettiEightOneTwentyAPCSeqToggle() end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120:APC Step Sequencer Toggle [Trigger]", invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyAPCSeqToggle() end end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Step Sequencer — Start", invoke=function() PakettiEightOneTwentyAPCSeqStart() end}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Groovebox:APC Step Sequencer — Stop",  invoke=function() PakettiEightOneTwentyAPCSeqStop() end}

-- 40 do-nothing absorbers for the APC pads (mirror the MidiMix "Disabled 01..16").
-- The APC bridge reads pads directly, but Renoise ALSO turns the pad notes into
-- played samples. Map each pad to one of these in Renoise MIDI Map mode and
-- Renoise consumes the note (no sample trigger) while the bridge still sequences.
for i = 1, 40 do
  renoise.tool():add_midi_mapping{
    name = string.format("Paketti:Paketti Groovebox 8120:Disabled APC %02d", i),
    invoke = function(message) end
  }
end

-- Auto-arm on groovebox open: if an APC Key 25 is connected, start the step
-- sequencer and tell the user. Silent when no APC is present.
function PakettiEightOneTwentyAPCAutoArm()
  local in_name = paketti_apc_find_device()
  if not in_name then return false end
  PakettiEightOneTwentyAPCSeqStart()
  renoise.app():show_status("Groovebox 8120: APC Key 25 detected — step sequencer ARMED. Map pads to 'Disabled APC NN' (MIDI Map mode) so they stop triggering samples.")
  return true
end

-- "Auto-Start AKAI APC Key 25" setting. When ON, the APC step sequencer is armed
-- at startup AND on every song load, so the pads work WITHOUT opening the 8120
-- dialog (the sequencer reads/writes the pattern headlessly). Persisted in prefs.
function PakettiEightOneTwentyAPCAutoStartEnabled()
  return preferences and preferences.PakettiEightOneTwentyAPCAutoStart
    and preferences.PakettiEightOneTwentyAPCAutoStart.value or false
end

function PakettiEightOneTwentyToggleAPCAutoStart()
  local now = not PakettiEightOneTwentyAPCAutoStartEnabled()
  if preferences and preferences.PakettiEightOneTwentyAPCAutoStart then
    preferences.PakettiEightOneTwentyAPCAutoStart.value = now
    preferences:save_as("preferences.xml")
  end
  if now then
    if not PakettiEightOneTwentyAPCAutoArm() then
      renoise.app():show_status("Auto-Start AKAI APC Key 25: ON — no APC connected yet (will arm when detected at next launch)")
    end
  else
    PakettiEightOneTwentyAPCSeqStop()
    renoise.app():show_status("Auto-Start AKAI APC Key 25: OFF — step sequencer stopped")
  end
end

PakettiAddMenuEntry{
  name = "Main Menu:Options:Auto-Start AKAI APC Key 25",
  selected = function() return PakettiEightOneTwentyAPCAutoStartEnabled() end,
  invoke = function() PakettiEightOneTwentyToggleAPCAutoStart() end
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Auto-Start AKAI APC Key 25",
  selected = function() return PakettiEightOneTwentyAPCAutoStartEnabled() end,
  invoke = function() PakettiEightOneTwentyToggleAPCAutoStart() end
}

-- Startup auto-arm: when the setting is ON, arm the APC once a document exists.
-- app_new_document fires on launch + song loads; AutoArm is silent if no APC.
local function paketti_apc_autostart_on_doc()
  if PakettiEightOneTwentyAPCAutoStartEnabled() and not paketti_apc_seq_active then
    PakettiEightOneTwentyAPCAutoArm()
  end
end
if not renoise.tool().app_new_document_observable:has_notifier(paketti_apc_autostart_on_doc) then
  renoise.tool().app_new_document_observable:add_notifier(paketti_apc_autostart_on_doc)
end
if PakettiEightOneTwentyAPCAutoStartEnabled() then
  local paketti_apc_autostart_timer
  paketti_apc_autostart_timer = function()
    renoise.tool():remove_timer(paketti_apc_autostart_timer)
    paketti_apc_autostart_on_doc()
  end
  renoise.tool():add_timer(paketti_apc_autostart_timer, 900)
end

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
    -- NOTE: do NOT close the MidiMix bridge here. The step sequencer + LEDs now
    -- work headlessly (read/write the pattern directly), so leaving the bridge
    -- open keeps the MidiMix driving steps + showing LEDs after the dialog is
    -- closed. Toggle it off explicitly with the "MidiMix Bridge Toggle" mapping.
    dialog:close()
    dialog = nil
    rows = {}
  else
    pakettiEightSlotsByOneTwentyDialog()
    if PakettiEightOneTwentyMidiMixOpen then PakettiEightOneTwentyMidiMixOpen() end
  end
end

renoise.tool():add_keybinding{name="Global:Paketti:Paketti Groovebox 8120",invoke=function() GrooveboxShowClose() end}
renoise.tool():add_midi_mapping{name="Paketti:Paketti Groovebox 8120",invoke=function(message) if message:is_trigger() then GrooveboxShowClose() end end }

-- Sequential Load family — trigger access (MIDI mapping + keybinding + menu).
-- These three actions fill all 8 rows in one go so they don't depend on a
-- focused-row selection: bind any to a controller button or key and you can
-- repopulate the entire 8120 from any state, including a fresh empty song.
local function paketti_8120_sequential_load_safe()
  if pakettiEightSlotsByOneTwentyDialog and not (dialog and dialog.visible) then
    pakettiEightSlotsByOneTwentyDialog()
  end
  loadSequentialSamplesWithFolderPrompts()
end
local function paketti_8120_sequential_random_safe()
  if pakettiEightSlotsByOneTwentyDialog and not (dialog and dialog.visible) then
    pakettiEightSlotsByOneTwentyDialog()
  end
  loadSequentialDrumkitSamples()
end
local function paketti_8120_sequential_random_all_safe()
  if pakettiEightSlotsByOneTwentyDialog and not (dialog and dialog.visible) then
    pakettiEightSlotsByOneTwentyDialog()
  end
  loadSequentialRandomLoadAll()
end
local function paketti_8120_clever_load_all_safe()
  if pakettiEightSlotsByOneTwentyDialog and not (dialog and dialog.visible) then
    pakettiEightSlotsByOneTwentyDialog()
  end
  loadSequentialKitAll()
end

renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 Sequential Load",
  invoke = paketti_8120_sequential_load_safe }
renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 Sequential RandomLoad",
  invoke = paketti_8120_sequential_random_safe }
renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 Sequential RandomLoadAll",
  invoke = paketti_8120_sequential_random_all_safe }
renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 Kit",
  invoke = paketti_8120_clever_load_all_safe }

renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Sequential Load [Trigger]",
  invoke = function(message) if message:is_trigger() then paketti_8120_sequential_load_safe() end end }
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Sequential RandomLoad [Trigger]",
  invoke = function(message) if message:is_trigger() then paketti_8120_sequential_random_safe() end end }
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Sequential RandomLoadAll [Trigger]",
  invoke = function(message) if message:is_trigger() then paketti_8120_sequential_random_all_safe() end end }
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Kit [Trigger]",
  invoke = function(message) if message:is_trigger() then paketti_8120_clever_load_all_safe() end end }

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Sequential Load (8 folders)…",
  invoke = paketti_8120_sequential_load_safe }
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Sequential RandomLoad (8 folders, random sample each)…",
  invoke = paketti_8120_sequential_random_safe }
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Sequential RandomLoadAll (1 folder, all 8 rows)…",
  invoke = paketti_8120_sequential_random_all_safe }
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Kit (1 folder, sorted into 8 drum categories)…",
  invoke = paketti_8120_clever_load_all_safe }

-- Toggle the empty-song auto-fill (Feature 2). Persisted to preferences.xml.
function PakettiEightOneTwentyToggleAutoFillDefaultSlots()
  local p = preferences and preferences.pakettiEightOneTwentyAutoFillDefaultSlots
  if not p then return end
  p.value = not p.value
  preferences:save_as("preferences.xml")
  renoise.app():show_status("Groovebox 8120: auto-fill default instrument slots on empty-song open is now " .. (p.value and "ON" or "OFF"))
end
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Toggle Auto-Fill Default Instrument Slots (empty song)",
  invoke = PakettiEightOneTwentyToggleAutoFillDefaultSlots }
renoise.tool():add_keybinding{name="Global:Paketti:Groovebox 8120 Toggle Auto-Fill Default Slots",invoke=PakettiEightOneTwentyToggleAutoFillDefaultSlots}

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
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Set flag to prevent automatic sample loader from running (we handle pakettification ourselves)
  PakettiDontRunAutomaticSampleLoader = true
  
  local folders = {}
  local current_folder = 1
  local dialog = nil
  local status_labels = {}
  
  -- Helper function to get just filename from path
  local function getFilename(filepath)
    -- Strip trailing slash if present
    local clean_path = filepath:gsub("[/\\]+$", "")
    return clean_path:match("([^/\\]+)%.%w+$") or clean_path:match("([^/\\]+)$") or clean_path
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
    instrument.name = string.format("8120_%02d Kit", instrument_index)
    
    return true
  end

  -- Main processing function
  local function process()

    for i = 1, 8 do
      if slicer:was_cancelled() then
        renoise.app():show_status("Sequential loading cancelled")
        -- Reset flag if cancelled
        PakettiDontRunAutomaticSampleLoader = false
        break
      end
      
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
        -- Add *Instr. Macros device to each track if enabled in preferences
        if preferences.pakettiLoaderDontCreateAutomationDevice.value == false then
          renoise.song().selected_track_index = i
          PakettiEightOneTwentyAddInstrMacrosToTrack(i)
        end
      end
    end
    
    update_instrument_list_and_popups()
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
    -- Reset flag after successful completion
    PakettiDontRunAutomaticSampleLoader = false
  end

  -- Function to start the processing
  local function startProcessing()
    -- Create ProcessSlicer
    slicer = ProcessSlicer(process)
    
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
        -- Reset flag if cancelled
        PakettiDontRunAutomaticSampleLoader = false
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
      -- Reset flag if cancelled
      PakettiDontRunAutomaticSampleLoader = false
      return
    end
  end

  -- Start by prompting for folders
  promptNextFolder()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to load samples sequentially from 8 folders using ProcessSlicer
function loadSequentialDrumkitSamples()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Set flag to prevent automatic sample loader from running (we handle pakettification ourselves)
  PakettiDontRunAutomaticSampleLoader = true
  
  local folders = {}
  local current_folder = 1
  local slicer = nil
  local dialog = nil
  local vb = nil
  local status_labels = {}
  
  -- Helper function to get just filename from path
  local function getFilename(filepath)
    -- Strip trailing slash if present
    local clean_path = filepath:gsub("[/\\]+$", "")
    return clean_path:match("([^/\\]+)%.%w+$") or clean_path:match("([^/\\]+)$") or clean_path
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
    
    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(instrument, "loadSequentialDrumkitSamples Part " .. instrument_index)

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
        pakettiSetViewStyle(status_labels[instrument_index], "strong")
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
        -- Reset flag if cancelled
        PakettiDontRunAutomaticSampleLoader = false
        break
      end
      
      -- Update status to show which part is processing
      for j = i + 1, 8 do
        local folder_name = getFilename(folders[j])
        status_labels[j].text = string.format("Part %d/8: Queued - Random from %s", j, folder_name)
        status_labels[j].font = "bold"
        pakettiSetViewStyle(status_labels[j], "strong")
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
          PakettiEightOneTwentyAddInstrMacrosToTrack(i)
        end
      end
    
    end
    
    update_instrument_list_and_popups()
    -- Switch back to pattern editor when done
   --renoise.app().window.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
    -- Reset flag after successful completion
    PakettiDontRunAutomaticSampleLoader = false
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
        -- Reset flag if cancelled
        PakettiDontRunAutomaticSampleLoader = false
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
      -- Reset flag if cancelled
      PakettiDontRunAutomaticSampleLoader = false
      return
    end
  end

  -- Start by prompting for folders
  promptNextFolder()
  
  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- Function to load samples sequentially from ONE folder for all 8 parts (RandomLoadAll)
function loadSequentialRandomLoadAll()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()
  
  -- Set flag to prevent automatic sample loader from running (we handle pakettification ourselves)
  PakettiDontRunAutomaticSampleLoader = true
  
  local base_folder = renoise.app():prompt_for_path("Select a single base folder for RandomLoadAll (used for all 8 parts)")
  if not base_folder then
    renoise.app():show_status("RandomLoadAll cancelled - no folder selected")
    -- Reset flag if cancelled
    PakettiDontRunAutomaticSampleLoader = false
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
    -- Strip trailing slash if present
    local clean_path = filepath:gsub("[/\\]+$", "")
    return clean_path:match("([^/\\]+)%.%w+$") or clean_path:match("([^/\\]+)$") or clean_path
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
    
    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(instrument, "loadSequentialRandomLoadAll Part " .. instrument_index)

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
        pakettiSetViewStyle(status_labels[instrument_index], "strong")
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
        -- Reset flag if cancelled
        PakettiDontRunAutomaticSampleLoader = false
        break
      end

      for j = i + 1, 8 do
        local folder_name = getFilename(folders[j])
        status_labels[j].text = string.format("Part %d/8: Queued - Random from %s", j, folder_name)
        status_labels[j].font = "bold"
        pakettiSetViewStyle(status_labels[j], "strong")
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
          PakettiEightOneTwentyAddInstrMacrosToTrack(i)
        end
      end
    end

    update_instrument_list_and_popups()
    renoise.app():show_status("Sequential loading completed - All instruments loaded")
    -- Reset flag after successful completion
    PakettiDontRunAutomaticSampleLoader = false
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
      -- Reset flag if cancelled
      PakettiDontRunAutomaticSampleLoader = false
    end})

    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Sequential Load Progress Dialog", dialog_content, keyhandler)
    slicer:start()
  end

  startProcessing()

  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
end

-- ============================================================================
-- Kit — category-aware RandomLoadAll
-- ----------------------------------------------------------------------------
-- Like Sequential RandomLoadAll (one base folder, fills all 8 rows), but instead
-- of dumping random samples into every row it sorts the folder's samples by drum
-- TYPE using filename keywords and gives each row a category: row 1 kicks, row 2
-- snares, row 3 hihats, row 4 claps, row 5 rides, row 6 perc, row 7 rimshots,
-- row 8 toms/cymbals/misc. Each row gets up to 120 of its own type, so you end up
-- with a ready-to-play drum machine where every row is a known style. The folder
-- is scanned recursively (subpaths included). Each file is assigned to the FIRST
-- category it matches (row order = priority), so a kick never doubles as "Other".

-- Editable category table. Keywords match case-insensitively at a leading token
-- boundary (preceded by start-of-name or a non-letter), so "SN" matches "SN_01"
-- and "Snare" but not "bassnote".
PakettiEightOneTwentyKitCategories = {
  { name = "Kick",    keywords = {"KICK","KCK","BD","BASSDRUM","BASS DRUM","KICKDRUM"} },
  { name = "Snare",   keywords = {"SNARE","SNAR","SNR","SN"} },
  { name = "Hihat",   keywords = {"HIHAT","HAT","HH","HIT","CLOSEDHAT"} },
  { name = "Clap",    keywords = {"CLAP","CLP","CLA","HANDCLAP"} },
  { name = "Ride",    keywords = {"RIDE","RIDECYMBAL"} },
  { name = "Perc",    keywords = {"PERC","PERCUSSION","PRC","CONGA","BONGO","TIMBALE"} },
  { name = "Rimshot", keywords = {"RIMSHOT","RIMS","RIM"} },
  { name = "Other",   keywords = {"TOM","CRASH","CYMBAL","CYM","OPENHAT","OPEN HAT","COWBELL","SHAKER","TAMB","CLAVE","SHKR"} },
}

-- Widest category name, so the "[name]" field can be space-padded to a fixed
-- width and every status line's "Loading/Queued ..." starts at the same column.
PakettiEightOneTwentyKitCatNameWidth = 0
for _, c in ipairs(PakettiEightOneTwentyKitCategories) do
  if #c.name > PakettiEightOneTwentyKitCatNameWidth then PakettiEightOneTwentyKitCatNameWidth = #c.name end
end

-- Returns "[Kick]   " / "[Rimshot]" — bracketed name padded to a fixed width.
function PakettiEightOneTwentyKitCatLabel(name)
  return "[" .. name .. "]" .. string.rep(" ", PakettiEightOneTwentyKitCatNameWidth - #name)
end

-- True if name_upper contains any keyword at a leading token boundary.
function PakettiEightOneTwentyCleverNameMatches(name_upper, keywords)
  for _, kw in ipairs(keywords) do
    local start = 1
    while true do
      local s = name_upper:find(kw, start, true)  -- plain substring search
      if not s then break end
      local before = (s > 1) and name_upper:sub(s - 1, s - 1) or ""
      if before == "" or not before:match("%a") then return true end
      start = s + 1
    end
  end
  return false
end

function loadSequentialKitAll()
  -- Temporarily disable AutoSamplify monitoring to prevent interference
  local AutoSamplifyMonitoringState = PakettiTemporarilyDisableNewSampleMonitoring()

  -- We pakettify ourselves, so keep the automatic sample loader out of the way
  PakettiDontRunAutomaticSampleLoader = true

  local base_folder = renoise.app():prompt_for_path("Select a single base folder for Kit (sorted into the 8 drum categories)")
  if not base_folder then
    renoise.app():show_status("Kit cancelled - no folder selected")
    PakettiDontRunAutomaticSampleLoader = false
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

  math.randomseed(os.time())
  math.random(); math.random(); math.random()

  local function getFilename(filepath)
    local clean_path = filepath:gsub("[/\\]+$", "")
    return clean_path:match("([^/\\]+)%.%w+$") or clean_path:match("([^/\\]+)$") or clean_path
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

  -- Scan once (recursive — find/dir already walk subpaths), then bucket every
  -- file into the FIRST category whose keywords its filename matches.
  local all_files = PakettiGetFilesInDirectory(base_folder)
  if #all_files == 0 then
    renoise.app():show_status("Kit: no audio files found in " .. base_folder)
    PakettiDontRunAutomaticSampleLoader = false
    PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
    return
  end

  local cats = PakettiEightOneTwentyKitCategories
  local buckets = {}
  for i = 1, 8 do buckets[i] = {} end

  for _, filepath in ipairs(all_files) do
    local name_upper = getFilename(filepath):upper()
    for i = 1, 8 do
      if PakettiEightOneTwentyCleverNameMatches(name_upper, cats[i].keywords) then
        table.insert(buckets[i], filepath)
        break
      end
    end
  end

  -- Report the per-category counts up front (also surfaces empty categories).
  do
    local parts = {}
    for i = 1, 8 do table.insert(parts, string.format("%s %d", cats[i].name, #buckets[i])) end
    print("Kit buckets: " .. table.concat(parts, ", "))
  end

  local slicer = nil
  local dialog = nil
  local status_labels = {}

  local function processInstrument(instrument_index, files_for_row, category_name)
    local song=renoise.song()
    song.selected_track_index = instrument_index
    song.selected_instrument_index = instrument_index
    local instrument = song.selected_instrument

    local defaultInstrument = preferences.pakettiDefaultDrumkitXRNI.value
    renoise.app():load_instrument(defaultInstrument)
    instrument = song.selected_instrument
    instrument.name = string.format("8120_%02d %s", instrument_index, category_name)
    instrument.macros_visible = true

    -- Apply modulation settings using helper function
    PakettiApplyLoaderModulationSettings(instrument, "loadSequentialKitAll Part " .. instrument_index)

    -- Work on a copy so we can random-pick without repeats.
    local pool = {}
    for _, f in ipairs(files_for_row) do table.insert(pool, f) end

    if #pool == 0 then
      if dialog and dialog.visible then
        status_labels[instrument_index].text = string.format("Part %d/8 %s: no matching samples found", instrument_index, PakettiEightOneTwentyKitCatLabel(category_name))
        status_labels[instrument_index].font = "bold"
        pakettiSetViewStyle(status_labels[instrument_index], "strong")
      end
      print(string.format("Kit Part %d [%s]: no matching samples", instrument_index, category_name))
      return true, 0
    end

    local max_samples = 120
    local num_samples_to_load = math.min(#pool, max_samples)
    local failed_files = {}

    for i = 1, num_samples_to_load do
      local random_index = math.random(1, #pool)
      local selected_file = pool[random_index]
      table.remove(pool, random_index)

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
            sample.new_note_action = 1
          end
          if preferences.pakettiLoaderLoopMode then sample.loop_mode = preferences.pakettiLoaderLoopMode.value end
          if preferences.pakettiLoaderLoopExit then sample.loop_release = preferences.pakettiLoaderLoopExit.value end
        end
      end

      if not ok or load_failed then
        print(string.format("Kit FAILED Part %d [%s] [%d/%d]: PATH: %s SIZE: %s",
          instrument_index, category_name, i, num_samples_to_load, selected_file, formatFileSize(file_size)))
        table.insert(failed_files, {index=i, path=selected_file, size=file_size, error=error_msg})
      end

      if dialog and dialog.visible then
        local display_name = capFilename(getFilename(selected_file))
        status_labels[instrument_index].text = string.format("Part %d/8 %s: Loading %03d/%03d: %s",
          instrument_index, PakettiEightOneTwentyKitCatLabel(category_name), i, num_samples_to_load, display_name)
        status_labels[instrument_index].font = "bold"
        pakettiSetViewStyle(status_labels[instrument_index], "strong")
      end

      if i % 5 == 0 then
        coroutine.yield()
      end
    end

    return true, num_samples_to_load
  end

  local loaded_counts = {}

  local function process()
    for i = 1, 8 do
      if slicer:was_cancelled() then
        renoise.app():show_status("Kit cancelled")
        PakettiDontRunAutomaticSampleLoader = false
        break
      end

      for j = i + 1, 8 do
        status_labels[j].text = string.format("Part %d/8 %s: Queued (%d matches)", j, PakettiEightOneTwentyKitCatLabel(cats[j].name), #buckets[j])
        status_labels[j].font = "bold"
        pakettiSetViewStyle(status_labels[j], "strong")
      end

      local success, loaded = processInstrument(i, buckets[i], cats[i].name)
      loaded_counts[i] = loaded or 0

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
          PakettiEightOneTwentyAddInstrMacrosToTrack(i)
        end
      end
    end

    update_instrument_list_and_popups()

    local summary = {}
    for i = 1, 8 do table.insert(summary, string.format("%s %d", cats[i].name, loaded_counts[i] or 0)) end
    renoise.app():show_status("Kit complete — " .. table.concat(summary, ", "))
    PakettiDontRunAutomaticSampleLoader = false
  end

  local function startProcessing()
    slicer = ProcessSlicer(process)
    local vb = renoise.ViewBuilder()
    local DEFAULT_MARGIN=renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
    local DEFAULT_SPACING=renoise.ViewBuilder.DEFAULT_CONTROL_SPACING

    local dialog_content = vb:column{margin=DEFAULT_MARGIN, spacing=DEFAULT_SPACING}
    for i = 1, 8 do
      local status_label = vb:text{ text = string.format("Part %d/8 %s: Queued (%d matches)", i, PakettiEightOneTwentyKitCatLabel(cats[i].name), #buckets[i]), font = "bold", style = "strong" }
      status_labels[i] = status_label
      dialog_content:add_child(status_label)
    end
    dialog_content:add_child(vb:button{ text = "Cancel", width = 80, notifier = function()
      slicer:cancel()
      if dialog and dialog.visible then dialog:close() end
      renoise.app():show_status("Kit cancelled by user")
      PakettiDontRunAutomaticSampleLoader = false
    end})

    local keyhandler = create_keyhandler_for_dialog(
      function() return dialog end,
      function(value) dialog = value end
    )
    dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 Kit Progress", dialog_content, keyhandler)
    slicer:start()
  end

  startProcessing()

  -- Restore AutoSamplify monitoring state
  PakettiRestoreNewSampleMonitoring(AutoSamplifyMonitoringState)
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

--------------------------------------------------------------------------------
-- PHRASE OUTPUT MODE FUNCTIONS (PhraseGrid Integration)
--------------------------------------------------------------------------------

-- Set the output mode for 8120
function PakettiEightOneTwentySetOutputMode(mode)
  local valid_modes = {pattern=true, phrase=true, phrase_trigger=true}
  if valid_modes[mode] then
    PakettiEightOneTwentyOutputMode = mode
    renoise.app():show_status("8120 Output Mode: " .. mode)
  else
    renoise.app():show_status("Invalid 8120 output mode: " .. tostring(mode))
  end
end

-- Cycle through output modes
function PakettiEightOneTwentyCycleOutputMode()
  local modes = {"pattern", "phrase", "phrase_trigger"}
  local current_index = 1
  for i, mode in ipairs(modes) do
    if mode == PakettiEightOneTwentyOutputMode then
      current_index = i
      break
    end
  end
  local next_index = (current_index % #modes) + 1
  PakettiEightOneTwentySetOutputMode(modes[next_index])
end

-- Write a single row's checkbox state to a phrase
function PakettiEightOneTwentyRowToPhrase(row_index)
  local song = renoise.song()
  if not song then return end
  
  if not rows or not rows[row_index] then
    renoise.app():show_status("8120 row " .. row_index .. " not available")
    return
  end
  
  local row_elements = rows[row_index]
  local instrument_index = row_elements.instrument_popup.value
  local instrument = song.instruments[instrument_index]
  
  if not instrument then
    renoise.app():show_status("Invalid instrument for row " .. row_index)
    return
  end
  
  local steps = row_elements.valuebox.value
  
  -- Create new phrase at end of phrase list
  local phrase_count = #instrument.phrases
  local new_phrase_index = phrase_count + 1
  instrument:insert_phrase_at(new_phrase_index)
  
  local phrase = instrument.phrases[new_phrase_index]
  phrase.number_of_lines = steps
  phrase.lpb = song.transport.lpb
  phrase.name = string.format("8120 Row %d", row_index)
  
  -- Ensure effect column is visible if needed
  local has_yxx = false
  for line = 1, math.min(MAX_STEPS, steps) do
    if row_elements.yxx_checkboxes[line] and row_elements.yxx_checkboxes[line].value then
      has_yxx = true
      break
    end
  end
  if has_yxx then
    phrase.sample_effects_column_visible = true
  end
  
  -- Write notes and effects to phrase
  for line = 1, math.min(MAX_STEPS, steps) do
    local note_checkbox_value = row_elements.checkboxes[line] and row_elements.checkboxes[line].value
    local yxx_checkbox_value = row_elements.yxx_checkboxes[line] and row_elements.yxx_checkboxes[line].value
    
    local phrase_line = phrase:line(line)
    local note_col = phrase_line:note_column(1)
    
    if note_checkbox_value then
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = instrument_index - 1
      
      if yxx_checkbox_value and row_elements.yxx_valuebox then
        note_col.effect_number_value = 0x19  -- Y command (sample offset fine)
        note_col.effect_amount_value = row_elements.yxx_valuebox.value
      end
    end
  end
  
  -- Set phrase as selected
  song.selected_instrument_index = instrument_index
  song.selected_phrase_index = new_phrase_index
  
  renoise.app():show_status(string.format("Created phrase %02d from 8120 row %d (%d steps)", new_phrase_index, row_index, steps))
  return new_phrase_index
end

-- Write all 8 rows to phrases (one phrase per row) and create a PhraseGrid bank
function PakettiEightOneTwentyAllRowsToPhrasesBank()
  local song = renoise.song()
  if not song then return end
  
  if not rows or #rows == 0 then
    renoise.app():show_status("8120 not initialized - open the dialog first")
    return
  end
  
  local phrases_created = {}
  
  for row_index = 1, 8 do
    if rows[row_index] then
      local phrase_index = PakettiEightOneTwentyRowToPhrase(row_index)
      if phrase_index then
        phrases_created[row_index] = phrase_index
      end
    end
  end
  
  -- Create a PhraseGrid bank if PhraseWorkflow is available
  if PakettiPhraseBankCreate then
    local bank_index = PakettiPhraseBankCreate(song.selected_instrument_index, "8120 Bank")
    if bank_index and PakettiPhraseBanks[bank_index] then
      -- Assign the created phrases to bank slots
      for row_index, phrase_index in pairs(phrases_created) do
        PakettiPhraseBankSetSlot(bank_index, row_index, phrase_index)
      end
      renoise.app():show_status(string.format("Created 8120 Bank with %d phrases", #phrases_created))
    end
  else
    renoise.app():show_status(string.format("Created %d phrases from 8120 rows", #phrases_created))
  end
  
  return phrases_created
end

-- Write row to pattern with phrase trigger mode (Zxx commands)
function PakettiEightOneTwentyRowToPhraseTriggersInPattern(row_index, phrase_index)
  local song = renoise.song()
  if not song then return end
  
  if not rows or not rows[row_index] then
    renoise.app():show_status("8120 row " .. row_index .. " not available")
    return
  end
  
  local row_elements = rows[row_index]
  local instrument_index = row_elements.instrument_popup.value
  local track_index = track_indices[row_elements.track_popup.value]
  
  if not track_index then
    renoise.app():show_status("Invalid track for row " .. row_index)
    return
  end
  
  phrase_index = phrase_index or row_index  -- Default: phrase index = row index
  
  local pattern = song.selected_pattern
  local pattern_length = pattern.number_of_lines
  local steps = row_elements.valuebox.value
  local track_in_pattern = pattern.tracks[track_index]
  local track = song.tracks[track_index]
  
  -- Ensure sample effects column is visible for Zxx
  track.sample_effects_column_visible = true
  
  -- Clear track first
  for line = 1, pattern_length do
    local note_col = track_in_pattern:line(line).note_columns[1]
    note_col:clear()
  end
  
  -- Write phrase triggers where checkboxes are checked
  for line = 1, math.min(MAX_STEPS, steps) do
    local note_checkbox_value = row_elements.checkboxes[line] and row_elements.checkboxes[line].value
    
    if note_checkbox_value then
      local note_col = track_in_pattern:line(line).note_columns[1]
      note_col.note_value = 48  -- C-4
      note_col.instrument_value = instrument_index - 1
      -- Add Zxx phrase program command
      note_col.effect_number_value = 0x23  -- Z command (phrase trigger)
      note_col.effect_amount_value = phrase_index
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
      end
    end
    -- Fill the trailing partial block so the final pattern rows aren't left
    -- empty (e.g. 64 lines / 3 steps = 21 full blocks + 1 leftover last row).
    local remainder = pattern_length - full_repeats * steps
    if remainder > 0 then
      local start_line = full_repeats * steps + 1
      for line = 1, math.min(remainder, MAX_STEPS) do
        local source_line = track_in_pattern:line(line)
        local dest_line = track_in_pattern:line(start_line + line - 1)
        dest_line.note_columns[1]:copy_from(source_line.note_columns[1])
      end
    end
  end

  renoise.app():show_status(string.format("8120 row %d: phrase trigger Z%02X written to pattern", row_index, phrase_index))
end

-- Get snapshot of current 8120 checkbox states for a row
function PakettiEightOneTwentyGetRowSnapshot(row_index)
  if not rows or not rows[row_index] then
    return nil
  end
  
  local row_elements = rows[row_index]
  local snapshot = {
    checkboxes = {},
    yxx_checkboxes = {},
    steps = row_elements.valuebox and row_elements.valuebox.value or MAX_STEPS,
    instrument = row_elements.instrument_popup and row_elements.instrument_popup.value or row_index,
    track = row_elements.track_popup and row_elements.track_popup.value or row_index,
    yxx_value = row_elements.yxx_valuebox and row_elements.yxx_valuebox.value or 0
  }
  
  for i = 1, MAX_STEPS do
    snapshot.checkboxes[i] = row_elements.checkboxes[i] and row_elements.checkboxes[i].value or false
    snapshot.yxx_checkboxes[i] = row_elements.yxx_checkboxes[i] and row_elements.yxx_checkboxes[i].value or false
  end
  
  return snapshot
end

-- Get snapshot of all 8120 rows
function PakettiEightOneTwentyGetFullSnapshot()
  local snapshot = {
    rows = {}
  }
  
  for row_index = 1, 8 do
    snapshot.rows[row_index] = PakettiEightOneTwentyGetRowSnapshot(row_index)
  end
  
  return snapshot
end

-- Restore 8120 row from snapshot
function PakettiEightOneTwentyRestoreRowFromSnapshot(row_index, snapshot)
  if not rows or not rows[row_index] then
    return false
  end
  
  if not snapshot then
    return false
  end
  
  local row_elements = rows[row_index]
  
  -- Restore checkboxes
  row_elements.updating_checkboxes = true
  row_elements.updating_yxx_checkboxes = true
  
  for i = 1, MAX_STEPS do
    if row_elements.checkboxes[i] then
      row_elements.checkboxes[i].value = snapshot.checkboxes[i] or false
    end
    if row_elements.yxx_checkboxes[i] then
      row_elements.yxx_checkboxes[i].value = snapshot.yxx_checkboxes[i] or false
    end
  end
  
  -- Restore other values
  if row_elements.valuebox and snapshot.steps then
    row_elements.valuebox.value = snapshot.steps
    row_elements.selected_step = (snapshot.steps == MAX_STEPS) and nil or snapshot.steps
    update_row_button_colors(row_elements)
  end
  
  if row_elements.instrument_popup and snapshot.instrument then
    row_elements.instrument_popup.value = snapshot.instrument
  end
  
  if row_elements.yxx_valuebox and snapshot.yxx_value then
    row_elements.yxx_valuebox.value = snapshot.yxx_value
    if row_elements.yxx_slider then
      row_elements.yxx_slider.value = snapshot.yxx_value
    end
  end
  
  row_elements.updating_checkboxes = false
  row_elements.updating_yxx_checkboxes = false
  
  -- Update pattern
  row_elements.print_to_pattern()
  
  return true
end

-- Restore all 8120 rows from full snapshot
function PakettiEightOneTwentyRestoreFromFullSnapshot(snapshot)
  if not snapshot or not snapshot.rows then
    return false
  end
  
  for row_index = 1, 8 do
    if snapshot.rows[row_index] then
      PakettiEightOneTwentyRestoreRowFromSnapshot(row_index, snapshot.rows[row_index])
    end
  end
  
  renoise.app():show_status("Restored 8120 state from snapshot")
  return true
end

-- Keybindings for phrase output mode
renoise.tool():add_keybinding{name="Global:Paketti:8120 Cycle Output Mode", invoke=PakettiEightOneTwentyCycleOutputMode}
renoise.tool():add_keybinding{name="Global:Paketti:8120 All Rows to Phrases Bank", invoke=PakettiEightOneTwentyAllRowsToPhrasesBank}

-- Individual row to phrase keybindings
for i = 1, 8 do
  renoise.tool():add_keybinding{
    name="Global:Paketti:8120 Row " .. i .. " to Phrase",
    invoke=function() PakettiEightOneTwentyRowToPhrase(i) end
  }
end

-- Phrase Trigger Mode keybindings (write Zxx commands to pattern for each row)
for i = 1, 8 do
  renoise.tool():add_keybinding{
    name="Global:Paketti:8120 Row " .. i .. " as Phrase Trigger (Z" .. string.format("%02X", i) .. ")",
    invoke=function() PakettiEightOneTwentyRowToPhraseTriggersInPattern(i, i) end
  }
end

-- Write all rows with phrase triggers
function PakettiEightOneTwentyAllRowsAsPhraseTriggersToPattern()
  local song = renoise.song()
  if not song then return end
  
  if not rows or #rows == 0 then
    renoise.app():show_status("8120 not initialized - open the dialog first")
    return
  end
  
  local triggers_written = 0
  for row_index = 1, 8 do
    if rows[row_index] then
      PakettiEightOneTwentyRowToPhraseTriggersInPattern(row_index, row_index)
      triggers_written = triggers_written + 1
    end
  end
  
  renoise.app():show_status(string.format("Wrote phrase triggers for %d rows (Z01-Z08)", triggers_written))
end

renoise.tool():add_keybinding{name="Global:Paketti:8120 All Rows as Phrase Triggers", invoke=PakettiEightOneTwentyAllRowsAsPhraseTriggersToPattern}

-- MIDI mappings
renoise.tool():add_midi_mapping{name="Paketti:8120 Cycle Output Mode [Trigger]", invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyCycleOutputMode() end end}
renoise.tool():add_midi_mapping{name="Paketti:8120 All Rows to Phrases Bank [Trigger]", invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyAllRowsToPhrasesBank() end end}
renoise.tool():add_midi_mapping{name="Paketti:8120 All Rows as Phrase Triggers [Trigger]", invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyAllRowsAsPhraseTriggersToPattern() end end}

for i = 1, 8 do
  renoise.tool():add_midi_mapping{
    name="Paketti:8120 Row " .. i .. " to Phrase [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyRowToPhrase(i) end end
  }
  renoise.tool():add_midi_mapping{
    name="Paketti:8120 Row " .. i .. " as Phrase Trigger [Trigger]",
    invoke=function(message) if message:is_trigger() then PakettiEightOneTwentyRowToPhraseTriggersInPattern(i, i) end end
  }
end

-- =============================================================================
-- Groovebox 8120 — CANVAS VIEW (MK2)
-- =============================================================================
-- Alternate rendering of the same 8120 state, optimized for at-a-glance step
-- editing and selection-based operations. This lives inside the 8120 module
-- (instead of a separate file) so the canvas's verbs can call 8120's file-local
-- functions directly (random_gate, fill_empty_steps, clear_all, fetch_pattern,
-- reverse_all, random_all). Both the canvas view and the classic view edit the
-- same rows[] table — clicking a cell here fires 8120's own checkbox notifier
-- which writes to the pattern.
--
-- Visual rules:
--   - 8 lanes, each lane is a horizontal band of 16 (or 32) cells
--   - Cells 1-4 white, 5-8 black, 9-12 white, 13-16 black (and the same
--     pattern doubled in 32-step mode)
--   - Active triggers render contrast-inverted inside the cell
--   - Selection: deep purple wash + bright purple border
--   - Step number labels are drawn LAST so nothing covers them
--   - Playhead: 2px amber border that preserves cell colors
--
-- Interaction:
--   - Click a cell to toggle the trigger
--   - Click + drag to range-select (within a row or across rows)
--   - Alt + click selects the entire 4-step quadrant containing the cell
--   - Shift + click extends the current selection to the cell
--   - Verb palette acts on the active selection

if PAKETTI_HAS_CANVAS then

-- (cv_dialog, cv_canvas, cv_ui are forward-declared at the top of the file
-- so file-local helpers above can reference them.)
cv_dialog = nil
cv_canvas = nil
cv_ui     = nil  -- holds widget references for live updates

local CV_NUM_LANES    = 8
local CV_CANVAS_W     = 960
local CV_LANE_H       = 28
local CV_CANVAS_H     = CV_NUM_LANES * CV_LANE_H
local CV_INSET_TOP    = 2
local CV_INNER_H      = CV_LANE_H - 4

local function cv_cell_w() return CV_CANVAS_W / MAX_STEPS end
local function cv_quad_dark(step) return (math.floor((step - 1) / 4) % 2) == 1 end

local function cv_rgb(r,g,b,a) return {r,g,b,a or 255} end
local CV_C = {
  bg            = cv_rgb(0x1e,0x1e,0x22),
  quad_white    = cv_rgb(0xe8,0xe8,0xec),
  quad_black    = cv_rgb(0x18,0x18,0x1c),
  trig_on_white = cv_rgb(0x18,0x18,0x1c),
  trig_on_black = cv_rgb(0xe8,0xe8,0xec),
  cell_grid     = cv_rgb(0x3a,0x3a,0x42),
  selection_fill= cv_rgb(0xb0,0x60,0xd8, 170),
  selection_brd = cv_rgb(0xc0,0x80,0xe8),
  playhead      = cv_rgb(0xff,0xb0,0x40),
  lane_div      = cv_rgb(0x4a,0x4a,0x54),
  muted_overlay = cv_rgb(0x18,0x18,0x1c, 130),
  step_label_l  = cv_rgb(0x6a,0x6a,0x70),
  step_label_d  = cv_rgb(0x9a,0x9a,0xa6),
}

-- 3x5 pixel digit glyphs for cell-corner labels.
local CV_DIGITS = {
  ["0"]={{1,1,1},{1,0,1},{1,0,1},{1,0,1},{1,1,1}},
  ["1"]={{0,1,0},{1,1,0},{0,1,0},{0,1,0},{1,1,1}},
  ["2"]={{1,1,1},{0,0,1},{1,1,1},{1,0,0},{1,1,1}},
  ["3"]={{1,1,1},{0,0,1},{1,1,1},{0,0,1},{1,1,1}},
  ["4"]={{1,0,1},{1,0,1},{1,1,1},{0,0,1},{0,0,1}},
  ["5"]={{1,1,1},{1,0,0},{1,1,1},{0,0,1},{1,1,1}},
  ["6"]={{1,1,1},{1,0,0},{1,1,1},{1,0,1},{1,1,1}},
  ["7"]={{1,1,1},{0,0,1},{0,1,0},{0,1,0},{0,1,0}},
  ["8"]={{1,1,1},{1,0,1},{1,1,1},{1,0,1},{1,1,1}},
  ["9"]={{1,1,1},{1,0,1},{1,1,1},{0,0,1},{1,1,1}},
}

local function cv_draw_number(ctx, n, x, y, px, color)
  ctx.fill_color = color
  local s = tostring(n)
  for i = 1, #s do
    local g = CV_DIGITS[s:sub(i, i)]
    if g then
      local x0 = x + (i - 1) * (4 * px)
      for r = 1, 5 do
        for c = 1, 3 do
          if g[r][c] == 1 then
            ctx:fill_rect(x0 + (c - 1) * px, y + (r - 1) * px, px, px)
          end
        end
      end
    end
  end
end

-- Selection state lives at module scope so verbs can read it.
local cv_selection = nil
local cv_drag = nil
local cv_mouse_down_pos = nil
local cv_mouse_did_drag = false
-- Yxx mode: when true, all read/write hits the yxx_checkboxes layer instead
-- of the note-trigger checkboxes. Lets the canvas edit Yxx effect commands
-- using the same selection model and verbs.
local cv_yxx_mode = false

local function cv_active_checkboxes(r)
  if not (rows and rows[r]) then return nil end
  if cv_yxx_mode then return rows[r].yxx_checkboxes end
  return rows[r].checkboxes
end

local function cv_read_trigger(r, s)
  local cbs = cv_active_checkboxes(r)
  if cbs and cbs[s] then return cbs[s].value and true or false end
  return false
end

local function cv_write_trigger(r, s, v)
  local cbs = cv_active_checkboxes(r)
  if cbs and cbs[s] then cbs[s].value = v and true or false end
end

-- Per-cell velocity (1..127, or nil for "default full"). Lives in the same
-- row_elements table 8120's pattern writer reads from, so the classic view
-- and the canvas always agree.
local function cv_read_velocity(r, s)
  if rows and rows[r] and rows[r].velocities then
    return rows[r].velocities[s]
  end
  return nil
end

local function cv_write_velocity(r, s, v)
  if rows and rows[r] and rows[r].velocities then
    rows[r].velocities[s] = v
    -- Re-fire the pattern writer so the new volume_value lands in the pattern.
    if rows[r].print_to_pattern then rows[r].print_to_pattern() end
  end
end

local function cv_read_solo(r)
  if rows and rows[r] and rows[r].solo_checkbox then
    return rows[r].solo_checkbox.value and true or false
  end
  return false
end

local function cv_set_solo(r, v)
  if rows and rows[r] and rows[r].solo_checkbox then
    rows[r].solo_checkbox.value = v and true or false
  end
end

local function cv_random_for_row(r)
  if rows and rows[r] and rows[r].random_button_pressed then
    rows[r].random_button_pressed()
  end
end

local function cv_read_row_steps(r)
  if rows and rows[r] and rows[r].valuebox then
    return rows[r].valuebox.value or MAX_STEPS
  end
  return MAX_STEPS
end

local function cv_set_row_steps(r, n)
  if rows and rows[r] and rows[r].valuebox then
    if n < 1 then n = 1 end
    if n > MAX_STEPS then n = MAX_STEPS end
    rows[r].valuebox.value = n
  end
end

local function cv_read_playhead(r)
  if rows and rows[r] and rows[r].play_step_index then
    return rows[r].play_step_index
  end
  return nil
end

-- Sample name (the loaded sample inside the active instrument), not the
-- instrument name. 8120's row tracks this in row_elements.sample_name_label
-- and updates it whenever the active sample changes.
local function cv_read_lane_name(r)
  if rows and rows[r] and rows[r].sample_name_label and rows[r].sample_name_label.text then
    local t = rows[r].sample_name_label.text
    if t and t ~= "" then return t end
  end
  if rows and rows[r] and rows[r].instrument_popup then
    local idx = rows[r].instrument_popup.value
    local song = renoise.song()
    if song and song.instruments[idx] and song.instruments[idx].name ~= "" then
      return song.instruments[idx].name
    end
  end
  return "—"
end

local function cv_read_lane_muted(r)
  if rows and rows[r] and rows[r].mute_checkbox then
    return rows[r].mute_checkbox.value and true or false
  end
  return false
end

local function cv_set_lane_muted(r, v)
  if rows and rows[r] and rows[r].mute_checkbox then
    rows[r].mute_checkbox.value = v and true or false
  end
end

local function cv_truncate(s, n)
  if not s then return "" end
  if #s <= n then return s end
  return s:sub(1, n - 1) .. "…"
end

local function cv_set_selection(r1, s1, r2, s2)
  if r2 < r1 then r1, r2 = r2, r1 end
  if s2 < s1 then s1, s2 = s2, s1 end
  cv_selection = { r1, s1, r2, s2 }
end

local function cv_update_selection_label()
  if not (cv_ui and cv_ui.selection_label) then return end
  if not cv_selection then
    cv_ui.selection_label.text = "selection: (none)"
    return
  end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  local cells = (r2 - r1 + 1) * (s2 - s1 + 1)
  if r1 == r2 then
    cv_ui.selection_label.text = string.format("selection: row %d · steps %d–%d (%d cells)", r1, s1, s2, cells)
  else
    cv_ui.selection_label.text = string.format("selection: rows %d–%d · steps %d–%d (%d cells)", r1, r2, s1, s2, cells)
  end
end

local function cv_draw_lane(ctx, row)
  local y0 = (row - 1) * CV_LANE_H + CV_INSET_TOP
  local cw = cv_cell_w()
  local quad_w = cw * 4

  for q = 0, (MAX_STEPS / 4) - 1 do
    ctx.fill_color = (q % 2 == 0) and CV_C.quad_white or CV_C.quad_black
    ctx:fill_rect(q * quad_w, y0, quad_w, CV_INNER_H)
  end

  ctx.stroke_color = CV_C.cell_grid
  ctx.line_width = 1
  for s = 1, MAX_STEPS - 1 do
    if (s % 4) ~= 0 then
      local x = s * cw
      ctx:begin_path(); ctx:move_to(x, y0); ctx:line_to(x, y0 + CV_INNER_H); ctx:stroke()
    end
  end

  -- Per-lane step count from the row's valuebox. Cells past this index render
  -- dimmed (still visible, but greyed) since they're outside the active loop.
  local row_steps = cv_read_row_steps(row)

  for s = 1, MAX_STEPS do
    if cv_read_trigger(row, s) then
      local v = cv_read_velocity(row, s)
      -- Trigger-mode cells render velocity as bar height. Yxx-mode cells
      -- render full because Yxx is boolean.
      local frac = (cv_yxx_mode or v == nil) and 1.0 or (v / 127)
      if frac < 0.05 then frac = 0.05 end
      local max_h = CV_INNER_H - 4
      local block_h = math.floor(max_h * frac)
      if block_h < 3 then block_h = 3 end
      local block_y = y0 + 2 + (max_h - block_h)
      local block_x = (s - 1) * cw + 3
      local block_w = cw - 6
      ctx.fill_color = cv_quad_dark(s) and CV_C.trig_on_black or CV_C.trig_on_white
      ctx:fill_rect(block_x, block_y, block_w, block_h)
    end
  end

  -- Cells past the per-row step count: dim overlay so user can see the
  -- inactive region.
  if row_steps < MAX_STEPS then
    local sx = row_steps * cw
    ctx.fill_color = CV_C.muted_overlay
    ctx:fill_rect(sx, y0, CV_CANVAS_W - sx, CV_INNER_H)
  end

  if cv_read_lane_muted(row) then
    ctx.fill_color = CV_C.muted_overlay
    ctx:fill_rect(0, y0, CV_CANVAS_W, CV_INNER_H)
  end

  if cv_selection then
    local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
    if row >= r1 and row <= r2 then
      local sx = (s1 - 1) * cw
      local sw = (s2 - s1 + 1) * cw
      ctx.fill_color = CV_C.selection_fill
      ctx:fill_rect(sx, y0, sw, CV_INNER_H)
      ctx.stroke_color = CV_C.selection_brd
      ctx.line_width = 2
      ctx:begin_path(); ctx:rect(sx, y0, sw, CV_INNER_H); ctx:stroke()
    end
  end

  -- Playhead — read from 8120's existing per-row play_step_index. 2px amber
  -- border preserving the cell's underlying colors.
  local ph = cv_read_playhead(row)
  if ph and ph >= 1 and ph <= MAX_STEPS then
    local px = (ph - 1) * cw
    ctx.stroke_color = CV_C.playhead
    ctx.line_width = 2.5
    ctx:begin_path(); ctx:rect(px, y0, cw, CV_INNER_H); ctx:stroke()
  end

  -- step number labels — drawn LAST so nothing covers them
  local label_px = (MAX_STEPS == 16) and 2 or 1
  for s = 1, MAX_STEPS do
    local color = cv_quad_dark(s) and CV_C.step_label_d or CV_C.step_label_l
    cv_draw_number(ctx, s, (s - 1) * cw + 3, y0 + 3, label_px, color)
  end

  if row < CV_NUM_LANES then
    ctx.stroke_color = CV_C.lane_div
    ctx.line_width = 1
    ctx:begin_path(); ctx:move_to(0, row * CV_LANE_H); ctx:line_to(CV_CANVAS_W, row * CV_LANE_H); ctx:stroke()
  end
end

local function cv_render(ctx)
  ctx:clear_rect(0, 0, CV_CANVAS_W, CV_CANVAS_H)
  ctx.fill_color = CV_C.bg
  ctx:fill_rect(0, 0, CV_CANVAS_W, CV_CANVAS_H)
  for r = 1, CV_NUM_LANES do cv_draw_lane(ctx, r) end
end

local function cv_hit_test(x, y)
  if x < 0 or x >= CV_CANVAS_W or y < 0 or y >= CV_CANVAS_H then return nil end
  local row = math.floor(y / CV_LANE_H) + 1
  local local_y = y - (row - 1) * CV_LANE_H
  if local_y < CV_INSET_TOP or local_y > CV_INSET_TOP + CV_INNER_H then return nil end
  local step = math.floor(x / cv_cell_w()) + 1
  if step < 1 then step = 1 end
  if step > MAX_STEPS then step = MAX_STEPS end
  return row, step
end

-- Double-click detection state.
local cv_last_click_t = 0
local cv_last_click_r = -1
local cv_last_click_s = -1
local CV_DOUBLECLICK_MS = 350

-- Velocity drag — when the user clicks an active trigger and drags vertically
-- INSIDE the cell, the y-position sets the velocity (top = full, bottom = min).
-- A drag that exits the cell or moves to a different cell falls back to range
-- selection like before.
local cv_velocity_drag = nil  -- {row, step, cell_top_y, cell_bottom_y}

local function cv_velocity_from_y(local_y, top, bottom)
  local span = bottom - top
  if span <= 0 then return 127 end
  local frac = 1.0 - ((local_y - top) / span)
  if frac < 0 then frac = 0 end
  if frac > 1 then frac = 1 end
  local v = math.floor(frac * 127 + 0.5)
  if v < 1 then v = 1 end
  return v
end

local function cv_handle_mouse(ev)
  if ev.type == "exit" then return end
  local mods = ev.modifiers or ""
  local has_alt   = mods:find("alt") or mods:find("option")
  local has_shift = mods:find("shift")

  if ev.type == "down" then
    local row, step = cv_hit_test(ev.position.x, ev.position.y)
    if not row then return end

    if has_alt then
      local q = math.floor((step - 1) / 4)
      cv_set_selection(row, q * 4 + 1, row, q * 4 + 4)
      cv_update_selection_label()
      if cv_canvas then cv_canvas:update() end
      return
    end
    if has_shift and cv_selection then
      cv_set_selection(cv_selection[1], cv_selection[2], row, step)
      cv_update_selection_label()
      if cv_canvas then cv_canvas:update() end
      return
    end

    -- Double-click detection: same cell, within window → set to full velocity.
    local now = os.clock() * 1000
    if row == cv_last_click_r and step == cv_last_click_s
        and (now - cv_last_click_t) < CV_DOUBLECLICK_MS
        and not cv_yxx_mode then
      cv_write_trigger(row, step, true)
      cv_write_velocity(row, step, nil)  -- nil = full / clean default
      cv_last_click_t = 0
      if cv_canvas then cv_canvas:update() end
      return
    end
    cv_last_click_t = now
    cv_last_click_r = row
    cv_last_click_s = step

    -- If clicking an already-active trigger in trigger mode, start a velocity
    -- drag inside the cell. The drag is committed on mouse-up; if the user
    -- moves to another cell, it falls back to range-select like before.
    if not cv_yxx_mode and cv_read_trigger(row, step) then
      local y0 = (row - 1) * CV_LANE_H + CV_INSET_TOP
      cv_velocity_drag = {
        row = row, step = step,
        cell_top = y0 + 2,
        cell_bottom = y0 + 2 + (CV_INNER_H - 4),
      }
      cv_set_selection(row, step, row, step)
      cv_update_selection_label()
      -- DON'T set velocity yet — wait for first move so a pure click stays
      -- clean (toggle off on up) while a click+drag adjusts velocity.
    end

    cv_mouse_down_pos = { row = row, step = step }
    cv_mouse_did_drag = false
    cv_drag = { anchor_row = row, anchor_step = step }
    cv_set_selection(row, step, row, step)
    cv_update_selection_label()
    if cv_canvas then cv_canvas:update() end

  elseif ev.type == "move" then
    if cv_velocity_drag then
      local row, step = cv_hit_test(ev.position.x, ev.position.y)
      if row == cv_velocity_drag.row and step == cv_velocity_drag.step then
        local v = cv_velocity_from_y(ev.position.y, cv_velocity_drag.cell_top, cv_velocity_drag.cell_bottom)
        cv_write_velocity(row, step, v)
        cv_mouse_did_drag = true   -- so mouse-up doesn't toggle the cell off
        if cv_canvas then cv_canvas:update() end
        return
      else
        -- Left the cell — drop velocity-drag, switch to range-select.
        cv_velocity_drag = nil
      end
    end
    if not cv_drag then return end
    local row, step = cv_hit_test(ev.position.x, ev.position.y)
    if not row then return end
    if row ~= cv_drag.anchor_row or step ~= cv_drag.anchor_step then
      cv_mouse_did_drag = true
    end
    cv_set_selection(cv_drag.anchor_row, cv_drag.anchor_step, row, step)
    cv_update_selection_label()
    if cv_canvas then cv_canvas:update() end

  elseif ev.type == "up" then
    if cv_velocity_drag then
      cv_velocity_drag = nil
      cv_drag = nil
      cv_mouse_down_pos = nil
      cv_mouse_did_drag = false
      return
    end
    if cv_mouse_down_pos and not cv_mouse_did_drag then
      local r, s = cv_mouse_down_pos.row, cv_mouse_down_pos.step
      cv_write_trigger(r, s, not cv_read_trigger(r, s))
      if cv_canvas then cv_canvas:update() end
    end
    cv_drag = nil
    cv_mouse_down_pos = nil
    cv_mouse_did_drag = false
  end
end

-- ----------- selection-scoped verbs -----------

local function cv_require_selection()
  if not cv_selection then
    renoise.app():show_status("Canvas View: drag a selection first")
    return false
  end
  return true
end

local function cv_each(fn)
  if not cv_selection then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  for r = r1, r2 do for s = s1, s2 do fn(r, s) end end
end

local function cv_refresh() if cv_canvas then cv_canvas:update() end end

local function cv_verb_invert()  if cv_require_selection() then cv_each(function(r,s) cv_write_trigger(r,s, not cv_read_trigger(r,s)) end); cv_refresh() end end
local function cv_verb_clear()   if cv_require_selection() then cv_each(function(r,s) cv_write_trigger(r,s,false) end); cv_refresh() end end
local function cv_verb_fill()    if cv_require_selection() then cv_each(function(r,s) cv_write_trigger(r,s,true)  end); cv_refresh() end end

local function cv_verb_reverse()
  if not cv_require_selection() then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  local n = s2 - s1 + 1
  for r = r1, r2 do
    local t = {}
    for s = s1, s2 do t[s - s1 + 1] = cv_read_trigger(r, s) end
    for s = s1, s2 do cv_write_trigger(r, s, t[n - (s - s1)]) end
  end
  cv_refresh()
end

local function cv_nudge(direction)
  if not cv_require_selection() then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  local n = s2 - s1 + 1
  for r = r1, r2 do
    local t = {}
    for s = s1, s2 do t[s - s1 + 1] = cv_read_trigger(r, s) end
    for s = s1, s2 do
      local idx = s - s1
      cv_write_trigger(r, s, t[((idx - direction) % n) + 1])
    end
  end
  cv_refresh()
end

local function cv_nudge_rows(direction)
  if not cv_require_selection() then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  local nrows = r2 - r1 + 1
  if nrows < 2 then
    renoise.app():show_status("Canvas View: row-nudge needs a multi-row selection")
    return
  end
  for s = s1, s2 do
    local t = {}
    for r = r1, r2 do t[r - r1 + 1] = cv_read_trigger(r, s) end
    for r = r1, r2 do
      local idx = r - r1
      cv_write_trigger(r, s, t[((idx - direction) % nrows) + 1])
    end
  end
  cv_refresh()
end

local cv_clipboard = nil
local function cv_verb_copy()
  if not cv_require_selection() then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  cv_clipboard = { rows = r2 - r1 + 1, steps = s2 - s1 + 1, cells = {} }
  for r = r1, r2 do
    local row_cells = {}
    for s = s1, s2 do table.insert(row_cells, cv_read_trigger(r, s)) end
    table.insert(cv_clipboard.cells, row_cells)
  end
  renoise.app():show_status(string.format("Canvas View: copied %dx%d", cv_clipboard.rows, cv_clipboard.steps))
end

local function cv_verb_paste()
  if not cv_clipboard then renoise.app():show_status("Canvas View: clipboard empty"); return end
  if not cv_require_selection() then return end
  local r1, s1 = cv_selection[1], cv_selection[2]
  for ri = 1, cv_clipboard.rows do
    for si = 1, cv_clipboard.steps do
      local rr, ss = r1 + ri - 1, s1 + si - 1
      if rr <= CV_NUM_LANES and ss <= MAX_STEPS then
        cv_write_trigger(rr, ss, cv_clipboard.cells[ri][si])
      end
    end
  end
  cv_refresh()
end

-- Euclidean fill into the selection.
local function cv_euclidean(k, n, offset)
  local pat = {}
  for i = 1, n do pat[i] = false end
  if k <= 0 then return pat end
  if k >= n then for i = 1, n do pat[i] = true end; return pat end
  for i = 0, k - 1 do
    local idx = math.floor(i * n / k) + 1
    pat[((idx - 1 + (offset or 0)) % n) + 1] = true
  end
  return pat
end

local function cv_show_euclid_dialog()
  if not cv_require_selection() then return end
  local r1, s1, r2, s2 = cv_selection[1], cv_selection[2], cv_selection[3], cv_selection[4]
  local n = s2 - s1 + 1
  local vb_local = renoise.ViewBuilder()
  local d = nil
  local pulses = vb_local:valuebox{ min=0, max=n, value=math.max(1, math.floor(n/4)) }
  local offset = vb_local:valuebox{ min=0, max=n-1, value=0 }
  local content = vb_local:column{
    margin = 6, spacing = 4,
    vb_local:text{ text=string.format("Euclidean fill across %d steps × %d rows", n, r2-r1+1), font="bold", style="strong" },
    vb_local:row{ vb_local:text{text="pulses ", width=60}, pulses },
    vb_local:row{ vb_local:text{text="offset ", width=60}, offset },
    vb_local:row{
      vb_local:button{ text="Apply", notifier=function()
        local pat = cv_euclidean(pulses.value, n, offset.value)
        for r = r1, r2 do for s = s1, s2 do cv_write_trigger(r, s, pat[s - s1 + 1]) end end
        cv_refresh()
        if d then d:close() end
      end },
      vb_local:button{ text="Cancel", notifier=function() if d then d:close() end end },
    }
  }
  d = renoise.app():show_custom_dialog("Euclidean Fill", content)
end

-- ----------- 8120 global-action verbs (call file-local 8120 fns directly) -----------

local function cv_verb_random_gate()       if not initializing then random_gate() end; cv_refresh() end
local function cv_verb_clear_all()         if not initializing then clear_all()  end; cv_refresh() end
local function cv_verb_fetch_pattern()     if not initializing then fetch_pattern() end; cv_refresh() end
local function cv_verb_reverse_all()       reverse_all(); cv_refresh() end
local function cv_verb_random_all()        random_all();  cv_refresh() end
local function cv_verb_randomize_all()     randomize_all(); cv_refresh() end
local function cv_verb_randomize_groove()  randomize_groove() end

-- ----------- dialog construction -----------

-- Sub-dialog: every per-row action and config that doesn't fit in the lane
-- strip. Opens via the ⋯ button on each lane. Calls 8120's existing per-row
-- functions (browse_instrument, select_instrument, show_automation, etc.)
-- and existing per-row widgets via the rows[] table.
local function cv_show_row_details(row)
  local re = rows and rows[row]
  if not re then
    renoise.app():show_status("Canvas View: classic 8120 dialog not open — open it first")
    return
  end
  local d = nil
  local vb_local = renoise.ViewBuilder()
  local function close() if d then d:close() end end

  local content = vb_local:column{
    margin = 8, spacing = 6,
    vb_local:text{
      text = string.format("Row %d — %s", row, cv_truncate(cv_read_lane_name(row), 40)),
      font = "bold", style = "strong"
    },
    vb_local:row{
      style = "panel",
      vb_local:text{ text = "Steps:", font="bold", style="strong" },
      vb_local:button{ text="<<", width=36, tooltip="Shift left", notifier=function()
        re.updating_checkboxes = true
        re.updating_yxx_checkboxes = true
        local first_n = re.checkboxes[1].value
        local first_y = re.yxx_checkboxes[1].value
        for i = 1, MAX_STEPS - 1 do
          re.checkboxes[i].value = re.checkboxes[i+1].value
          re.yxx_checkboxes[i].value = re.yxx_checkboxes[i+1].value
        end
        re.checkboxes[MAX_STEPS].value = first_n
        re.yxx_checkboxes[MAX_STEPS].value = first_y
        re.print_to_pattern()
        re.updating_checkboxes = false
        re.updating_yxx_checkboxes = false
        cv_refresh()
      end },
      vb_local:button{ text=">>", width=36, tooltip="Shift right", notifier=function()
        re.updating_checkboxes = true
        re.updating_yxx_checkboxes = true
        local last_n = re.checkboxes[MAX_STEPS].value
        local last_y = re.yxx_checkboxes[MAX_STEPS].value
        for i = MAX_STEPS, 2, -1 do
          re.checkboxes[i].value = re.checkboxes[i-1].value
          re.yxx_checkboxes[i].value = re.yxx_checkboxes[i-1].value
        end
        re.checkboxes[1].value = last_n
        re.yxx_checkboxes[1].value = last_y
        re.print_to_pattern()
        re.updating_checkboxes = false
        re.updating_yxx_checkboxes = false
        cv_refresh()
      end },
      vb_local:button{ text="Clear", width=64, notifier=function()
        re.updating_checkboxes = true
        re.updating_yxx_checkboxes = true
        for i = 1, MAX_STEPS do
          re.checkboxes[i].value = false
          re.yxx_checkboxes[i].value = false
          if re.velocities then re.velocities[i] = nil end
        end
        re.updating_checkboxes = false
        re.updating_yxx_checkboxes = false
        re.print_to_pattern()
        cv_refresh()
      end },
      vb_local:button{ text="Randomize", width=90, notifier=function()
        if re.randomize then re.randomize() end
        cv_refresh()
      end },
      vb_local:button{ text="Reverse Sample", width=120, notifier=function()
        reverse_sample(re); cv_refresh()
      end },
    },
    vb_local:row{
      style = "panel",
      vb_local:text{ text = "Sample:", font="bold", style="strong" },
      vb_local:button{ text="Load…", width=70, notifier=function()
        if re.browse_instrument then re.browse_instrument() end
      end },
      vb_local:button{ text="Show", width=60, notifier=function()
        if re.select_instrument then re.select_instrument() end
      end },
      vb_local:button{ text="Random", width=80, notifier=function()
        if re.random_button_pressed then re.random_button_pressed() end
      end },
      vb_local:button{ text="Automation", width=110, notifier=function()
        if re.show_automation then re.show_automation() end
      end },
    },
    -- Output delay — fresh widgets that read/write the song's track output_delay
    -- (and mirror the classic dialog's widgets via 8120's own observers).
    (function()
      local tracks = renoise.song().tracks
      local track_idx = (re.track_popup and re.track_popup.value) or row
      local current = (tracks[track_idx] and tracks[track_idx].output_delay) or 0
      local delay_label = vb_local:text{ text=string.format("%+04dms", current), font="bold", style="strong", width=60 }
      local delay_slider = vb_local:slider{
        min = -100, max = 100, value = current, width = 200,
        steps = pakettiSteps(1, -1),
        notifier = function(v)
          v = math.floor(v)
          delay_label.text = string.format("%+04dms", v)
          if tracks[track_idx] then tracks[track_idx].output_delay = v end
          if re.output_delay_slider then re.output_delay_slider.value = v end
          if re.output_delay_value_label then
            re.output_delay_value_label.text = string.format("%+04dms", v)
          end
        end
      }
      return vb_local:row{
        style = "panel",
        vb_local:text{ text = "Output Delay:", font="bold", style="strong" },
        delay_slider, delay_label,
        vb_local:button{ text="Reset", notifier=function()
          delay_slider.value = 0
          if tracks[track_idx] then tracks[track_idx].output_delay = 0 end
          if re.output_delay_slider then re.output_delay_slider.value = 0 end
        end },
      }
    end)(),
    -- Beatsync — read/write the active sample's beat_sync_enabled and lines.
    -- Mirrors 8120's beatsync_checkboxes[row] which uses the same sample.
    (function()
      local function active_sample()
        local inst_idx = (re.instrument_popup and re.instrument_popup.value) or row
        local inst = renoise.song().instruments[inst_idx]
        if not inst or not inst.samples or #inst.samples == 0 then return nil end
        for _, smp in ipairs(inst.samples) do
          local vr = smp.sample_mapping and smp.sample_mapping.velocity_range
          if vr and vr[1] == 0x00 and vr[2] == 0x7F then return smp end
        end
        return inst.samples[1]
      end
      local smp = active_sample()
      local enabled = smp and smp.beat_sync_enabled or false
      local lines = smp and smp.beat_sync_lines or 16
      local lines_box = vb_local:valuebox{
        min = 1, max = 512, value = lines, width = 60,
        notifier = function(v)
          local s = active_sample(); if s then s.beat_sync_lines = math.floor(v) end
        end
      }
      return vb_local:row{
        style = "panel",
        vb_local:text{ text = "Beatsync:", font="bold", style="strong" },
        vb_local:checkbox{ value = enabled, notifier = function(v)
          local s = active_sample(); if s then s.beat_sync_enabled = v end
        end },
        vb_local:text{ text = "lines:", style="strong" },
        lines_box,
      }
    end)(),
    -- Loop mode + loop range — read/write the active sample's loop_mode and
    -- loop_start/loop_end. Same logic as 8120's per-row loop switches.
    (function()
      local function active_sample()
        local inst_idx = (re.instrument_popup and re.instrument_popup.value) or row
        local inst = renoise.song().instruments[inst_idx]
        if not inst or not inst.samples or #inst.samples == 0 then return nil end
        for _, smp in ipairs(inst.samples) do
          local vr = smp.sample_mapping and smp.sample_mapping.velocity_range
          if vr and vr[1] == 0x00 and vr[2] == 0x7F then return smp end
        end
        return inst.samples[1]
      end
      local smp = active_sample()
      local mode_value = 1
      if smp then
        if     smp.loop_mode == renoise.Sample.LOOP_MODE_OFF       then mode_value = 1
        elseif smp.loop_mode == renoise.Sample.LOOP_MODE_FORWARD   then mode_value = 2
        elseif smp.loop_mode == renoise.Sample.LOOP_MODE_REVERSE   then mode_value = 3
        elseif smp.loop_mode == renoise.Sample.LOOP_MODE_PING_PONG then mode_value = 4
        end
      end
      local mode_switch = vb_local:switch{
        items = {"Off","→","←","↔"}, width = 140, value = mode_value,
        notifier = function(v)
          local s = active_sample(); if not s then return end
          if     v == 1 then s.loop_mode = renoise.Sample.LOOP_MODE_OFF
          elseif v == 2 then s.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
          elseif v == 3 then s.loop_mode = renoise.Sample.LOOP_MODE_REVERSE
          elseif v == 4 then s.loop_mode = renoise.Sample.LOOP_MODE_PING_PONG
          end
        end
      }
      local range_switch = vb_local:switch{
        items = {"[--]","[- ]","[ -]"}, width = 100, value = 1,
        notifier = function(v)
          local s = active_sample(); if not s then return end
          local buf = s.sample_buffer
          if not (buf and buf.has_sample_data) then return end
          local n = buf.number_of_frames or 0
          if n <= 1 then return end
          local half = math.floor(n / 2)
          if     v == 1 then s.loop_start = 1;    s.loop_end = n
          elseif v == 2 then s.loop_start = 1;    s.loop_end = half
          elseif v == 3 then s.loop_start = half; s.loop_end = n
          end
        end
      }
      return vb_local:row{
        style = "panel",
        vb_local:text{ text = "Loop:", font="bold", style="strong" },
        mode_switch,
        vb_local:text{ text = "range:", style="strong" },
        range_switch,
      }
    end)(),
    -- Yxx amount — fresh widgets read/write re.yxx_valuebox.value.
    (function()
      local current = (re.yxx_valuebox and re.yxx_valuebox.value) or 0
      local yxx_box = vb_local:valuebox{
        min = 0, max = 255, value = current, width = 60,
        notifier = function(v)
          if re.yxx_valuebox then re.yxx_valuebox.value = v end
          if re.yxx_slider then re.yxx_slider.value = v end
          if re.print_to_pattern then re.print_to_pattern() end
        end
      }
      local yxx_slider = vb_local:slider{
        min = 0, max = 255, value = current, width = 200,
        notifier = function(v)
          v = math.floor(v)
          yxx_box.value = v
        end
      }
      return vb_local:row{
        style = "panel",
        vb_local:text{ text = "Yxx amount:", font="bold", style="strong" },
        yxx_slider, yxx_box,
      }
    end)(),
    vb_local:row{
      vb_local:button{ text="Close", notifier=close },
    },
  }
  d = renoise.app():show_custom_dialog(string.format("Row %d details", row), content)
end

local function cv_lane_strip_left(row)
  local name      = cv_read_lane_name(row)
  local is_muted  = cv_read_lane_muted(row)
  local is_soloed = cv_read_solo(row)
  local mute_btn  = vb:button{
    text = "M", width = 22,
    color = is_muted and {0xd8,0x50,0x60} or nil,
    notifier = function()
      cv_set_lane_muted(row, not cv_read_lane_muted(row))
      cv_refresh()
    end
  }
  local solo_btn = vb:button{
    text = "S", width = 22,
    color = is_soloed and {0xff,0xb0,0x40} or nil,
    notifier = function()
      cv_set_solo(row, not cv_read_solo(row))
      cv_refresh()
    end
  }
  local random_btn = vb:button{
    text = "R", width = 22,
    tooltip = "Randomize this lane's steps",
    notifier = function() cv_random_for_row(row); cv_refresh() end
  }
  local more_btn = vb:button{
    text = "⋯", width = 22,
    tooltip = "Per-row details: shift, clear, randomize, load, show, automation, reverse, output delay, Yxx",
    notifier = function() cv_show_row_details(row) end
  }
  -- Per-row step count valuebox — same widget the classic 8120 uses.
  local steps_box = vb:valuebox{
    min = 1, max = MAX_STEPS, value = cv_read_row_steps(row), width = 42,
    tooltip = "Steps for this lane (per-row step count)",
    notifier = function(v) cv_set_row_steps(row, v); cv_refresh() end
  }
  return vb:row{
    height = CV_LANE_H,
    mute_btn, solo_btn, random_btn, more_btn,
    vb:text{ text=string.format(" %02d ", row), font="bold", style="strong", width=22 },
    steps_box,
    vb:text{ text=cv_truncate(name, 30), width=210, style=(name == "—") and "disabled" or "normal" },
  }
end

local function cv_lane_strip_right(row)
  local re = rows and rows[row]
  -- Sample slider — read-through to 8120's rows[row].slider.
  local slider_initial = (re and re.slider) and (re.slider.value or 1) or 1
  local sample_slider = vb:slider{
    min = 1, max = 120, value = slider_initial, width = 110,
    notifier = function(value)
      value = math.floor(value)
      if rows and rows[row] and rows[row].slider then
        rows[row].slider.value = value
      else
        local song = renoise.song()
        if row <= #song.instruments then
          song.selected_instrument_index = row
          local inst = song.instruments[row]
          if inst and inst.samples and #inst.samples > 0 then
            local idx = value
            if idx > #inst.samples then idx = #inst.samples end
            if idx < 1 then idx = 1 end
            song.selected_sample_index = idx
          end
        end
      end
    end
  }
  -- Pitch rotary — read-through to rows[row].transpose_rotary so it fires
  -- 8120's existing notifier (which writes instrument.transpose, restores
  -- automation, etc.).
  local pitch_initial = (re and re.transpose_rotary) and re.transpose_rotary.value or 0
  local pitch_rotary = vb:rotary{
    min = -64, max = 64, value = pitch_initial, width = 22, height = 22,
    tooltip = "Pitch (instrument transpose, semitones)",
    notifier = function(value)
      if rows and rows[row] and rows[row].transpose_rotary then
        rows[row].transpose_rotary.value = value
      end
    end
  }
  -- Volume rotary — same pattern. 8120's volume_rotary uses range -1..+1
  -- mapped to instrument volume 0..2 internally.
  local vol_initial = (re and re.volume_rotary) and re.volume_rotary.value or 0
  local vol_rotary = vb:rotary{
    min = -1, max = 1, value = vol_initial, width = 22, height = 22,
    tooltip = "Volume",
    notifier = function(value)
      if rows and rows[row] and rows[row].volume_rotary then
        rows[row].volume_rotary.value = value
      end
    end
  }
  return vb:row{
    height = CV_LANE_H,
    pitch_rotary,
    vol_rotary,
    vb:text{ text=" smp ", style="disabled", width=28 },
    sample_slider,
  }
end

local function cv_build_view()
  cv_canvas = vb:canvas{
    width = CV_CANVAS_W, height = CV_CANVAS_H,
    mode = "plain",
    render = cv_render,
    mouse_handler = cv_handle_mouse,
    mouse_events = {"down","up","move","exit"},
  }

  local left_col  = { spacing = 0, margin = 0 }
  local right_col = { spacing = 0, margin = 0 }
  for r = 1, CV_NUM_LANES do
    table.insert(left_col,  cv_lane_strip_left(r))
    table.insert(right_col, cv_lane_strip_right(r))
  end

  local function song_t() return renoise.song().transport end

  local u = {}
  u.bpm_label = vb:text{
    text = string.format("  BPM %d", math.floor((song_t().bpm or 120) + 0.5)),
    font = "bold", style = "strong"
  }
  u.selection_label = vb:text{ text = "selection: (none)", style="strong" }

  -- live BPM follow
  pcall(function()
    song_t().bpm_observable:add_notifier(function()
      if u.bpm_label and cv_dialog and cv_dialog.visible then
        u.bpm_label.text = string.format("  BPM %d", math.floor((song_t().bpm or 120) + 0.5))
      end
    end)
  end)

  -- Fill Empty Steps slider — same notifier 8120's classic uses; feeds
  -- fill_empty_steps(probability) (file-local) which writes triggers into
  -- empty cells across all rows.
  local fill_pct_label = vb:text{ text="Fill 0%", style="strong", font="bold", width=54 }
  local fill_slider = vb:slider{
    min = 0, max = 20, value = 0, width = 110,
    steps = pakettiSteps(0.1, -0.1),
    notifier = function(v)
      v = math.floor(v)
      fill_pct_label.text = string.format("Fill %d%%", v)
      if v == 0 then clear_all() else fill_empty_steps(v / 100) end
    end
  }

  -- Step mode toggle (16/32) — fires the existing toggle path so classic
  -- and canvas stay in sync. classic re-creates its dialog on toggle; the
  -- canvas just refreshes since it reads MAX_STEPS each render.
  local step_mode_btn = vb:button{
    text = string.format("%d steps", MAX_STEPS), width = 70,
    tooltip = "Toggle between 16-step and 32-step mode (classic dialog rebuilds; canvas keeps running)",
    notifier = function()
      MAX_STEPS = (MAX_STEPS == 16) and 32 or 16
      if dialog and dialog.visible then
        cleanup_bpm_observable()
        dialog:close()
        dialog = nil
        rows = {}
        pakettiEightSlotsByOneTwentyDialog()
      end
      if cv_canvas then cv_canvas:update() end
      renoise.app():show_status("Toggled to " .. MAX_STEPS .. " steps mode")
    end
  }

  local transport_bar = vb:row{
    style = "panel",
    vb:button{ text="▶", width=28, notifier=function() song_t():start(renoise.Transport.PLAYMODE_RESTART_PATTERN) end },
    vb:button{ text="■", width=28, notifier=function() song_t():stop() end },
    vb:button{ text="●", width=28, notifier=function() song_t().edit_mode = not song_t().edit_mode end },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="/2", width=28, notifier=divide_bpm },
    vb:button{ text="−",  width=24, notifier=decrease_bpm },
    u.bpm_label,
    vb:button{ text="+",  width=24, notifier=increase_bpm },
    vb:button{ text="×2", width=28, notifier=multiply_bpm },
    vb:text{ text="  follow", style="strong" },
    vb:checkbox{ value=song_t().follow_player and true or false, notifier=function(v) song_t().follow_player=v end },
    vb:text{ text="  groove", style="strong" },
    vb:checkbox{ value=song_t().groove_enabled and true or false, notifier=function(v) song_t().groove_enabled=v end },
    vb:text{ text=" |", style="disabled" },
    fill_pct_label, fill_slider,
    vb:text{ text=" |", style="disabled" },
    step_mode_btn,
    vb:button{ text="Duplicate Pattern", width=130, notifier=PakettiEightOneTwentyDuplicatePattern },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="MK2->MK1", width=70,
      tooltip = "Open the classic 8120 dialog with all controls. Both windows stay open and share state; close whichever you don't need via its X button.",
      notifier = function()
        if not (dialog and dialog.visible) then pakettiEightSlotsByOneTwentyDialog() end
      end },
  }

  -- Trig/Yxx mode toggle. Switching mode swaps which checkbox layer the
  -- canvas reads/writes (note triggers vs Yxx effect commands). Selection
  -- and verbs work the same way in both modes.
  -- Renoise's vb:button doesn't allow assigning .notifier after construction,
  -- so the closure captures a forward-declared `mode_btn` that's reassigned
  -- once the button exists.
  local mode_btn
  mode_btn = vb:button{
    text = cv_yxx_mode and "Mode: Yxx" or "Mode: Trig",
    width = 96,
    tooltip = "Toggle between editing the note-trigger row and the Yxx effect-command row.",
    notifier = function()
      cv_yxx_mode = not cv_yxx_mode
      mode_btn.text = cv_yxx_mode and "Mode: Yxx" or "Mode: Trig"
      cv_refresh()
    end
  }

  local verb_palette_1 = vb:row{
    style = "panel",
    mode_btn,
    vb:text{ text=" |", style="disabled" },
    vb:text{ text="step:", style="strong" },
    vb:button{ text="←", width=30, notifier=function() cv_nudge(-1) end },
    vb:button{ text="→", width=30, notifier=function() cv_nudge( 1) end },
    vb:text{ text=" row:", style="strong" },
    vb:button{ text="↑", width=30, notifier=function() cv_nudge_rows(-1) end },
    vb:button{ text="↓", width=30, notifier=function() cv_nudge_rows( 1) end },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="invert",   width=60, notifier=cv_verb_invert },
    vb:button{ text="reverse",  width=70, notifier=cv_verb_reverse },
    vb:button{ text="fill",     width=50, notifier=cv_verb_fill },
    vb:button{ text="clear",    width=50, notifier=cv_verb_clear },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="copy",     width=50, notifier=cv_verb_copy },
    vb:button{ text="paste",    width=50, notifier=cv_verb_paste },
    vb:button{ text="euclid…",  width=88, notifier=cv_show_euclid_dialog },
  }

  -- Live mini-sliders for transport.groove_amounts so "Random Groove" isn't
  -- a black box — user can also see and tweak the four values.
  local function song_t() return renoise.song().transport end
  local groove_widgets = {}
  local groove_value_labels = {}
  for i = 1, 4 do
    local g = (song_t().groove_amounts or {0,0,0,0})[i] or 0
    groove_value_labels[i] = vb:text{
      text = string.format("%2d%%", math.floor(g * 100 + 0.5)),
      style = "strong", width = 32
    }
    groove_widgets[i] = vb:slider{
      min = 0, max = 1, value = g, width = 56,
      notifier = function(value)
        local arr = {}
        for j = 1, 4 do
          arr[j] = (j == i) and value or ((song_t().groove_amounts or {0,0,0,0})[j] or 0)
        end
        song_t().groove_amounts = arr
        song_t().groove_enabled = true
        groove_value_labels[i].text = string.format("%2d%%", math.floor(value * 100 + 0.5))
      end
    }
  end

  local verb_palette_2 = vb:row{
    style = "panel",
    vb:text{ text="all-rows:", style="strong" },
    vb:button{ text="Random Gate",   width=100, notifier=cv_verb_random_gate },
    vb:button{ text="Clear All",     width=80,  notifier=cv_verb_clear_all },
    vb:button{ text="Fetch Pattern", width=110, notifier=cv_verb_fetch_pattern },
    vb:button{ text="Reverse All",   width=90,  notifier=cv_verb_reverse_all },
    vb:button{ text="Random All",    width=90,  notifier=cv_verb_random_all },
    vb:button{ text="Randomize All", width=110, notifier=cv_verb_randomize_all },
    vb:text{ text=" |", style="disabled" },
    vb:button{ text="Random Groove", width=110, notifier=function()
      cv_verb_randomize_groove()
      -- After randomizing, push the new transport values back into the mini-sliders.
      local arr = song_t().groove_amounts or {0,0,0,0}
      for i = 1, 4 do
        groove_widgets[i].value = arr[i] or 0
        groove_value_labels[i].text = string.format("%2d%%", math.floor((arr[i] or 0) * 100 + 0.5))
      end
    end },
    groove_widgets[1], groove_value_labels[1],
    groove_widgets[2], groove_value_labels[2],
    groove_widgets[3], groove_value_labels[3],
    groove_widgets[4], groove_value_labels[4],
  }

  local verb_palette_3 = vb:row{
    style = "panel",
    vb:text{ text="load:", style="strong" },
    vb:button{ text="Sequential Load",          width=130, notifier=function() loadSequentialSamplesWithFolderPrompts() end },
    vb:button{ text="Sequential RandomLoad",    width=170, notifier=function() loadSequentialDrumkitSamples() end },
    vb:button{ text="Sequential RandomLoadAll", width=190, notifier=function() loadSequentialRandomLoadAll() end },
  }

  -- Output Mode switch — pattern / phrase / phrase_trigger. Same setter the
  -- classic dialog and the cycle-output-mode keybinding use, so all three
  -- views agree on the current mode.
  local output_mode_value = 1
  if     PakettiEightOneTwentyOutputMode == "phrase"         then output_mode_value = 2
  elseif PakettiEightOneTwentyOutputMode == "phrase_trigger" then output_mode_value = 3 end
  local output_mode_switch = vb:switch{
    items = {"Pattern","Phrase","Phrase Trigger"},
    width = 220, value = output_mode_value,
    notifier = function(v)
      if     v == 1 then PakettiEightOneTwentySetOutputMode("pattern")
      elseif v == 2 then PakettiEightOneTwentySetOutputMode("phrase")
      elseif v == 3 then PakettiEightOneTwentySetOutputMode("phrase_trigger")
      end
    end
  }

  local verb_palette_4 = vb:row{
    style = "panel",
    vb:text{ text="output:", style="strong" },
    output_mode_switch,
    vb:text{ text=" |", style="disabled" },
    vb:text{ text="phrases:", style="strong" },
    vb:button{ text="All Rows → Phrases",         width=160, tooltip="Convert all 8 rows into phrases on their instruments",
      notifier = function() PakettiEightOneTwentyAllRowsToPhrasesBank() end },
    vb:button{ text="All Rows as Phrase Triggers", width=180, tooltip="Write phrase-trigger Zxx commands into the pattern",
      notifier = function() PakettiEightOneTwentyAllRowsAsPhraseTriggersToPattern() end },
    vb:text{ text=" |", style="disabled" },
    vb:text{ text="global pitch:", style="strong" },
    vb:button{ text="-12", width=40, notifier=function() PakettiGrooveboxGlobalPitch(-12) end },
    vb:button{ text="-1",  width=32, notifier=function() PakettiGrooveboxGlobalPitch(-1) end },
    vb:button{ text="0",   width=32, notifier=function() PakettiGrooveboxGlobalPitchAbsolute(0) end },
    vb:button{ text="+1",  width=32, notifier=function() PakettiGrooveboxGlobalPitch( 1) end },
    vb:button{ text="+12", width=40, notifier=function() PakettiGrooveboxGlobalPitch(12) end },
  }

  -- Expand / Shrink Replicate — operates on the *currently selected* track
  -- (so user picks which row's pattern to replicate via the track popup,
  -- then hits Expand or Shrink). The row-specific MIDI mappings already
  -- exist; this exposes them in canvas form.
  local expand_row_box = vb:valuebox{
    min = 1, max = 8, value = 1, width = 50,
    tooltip = "Which row to expand/shrink-replicate",
  }
  local verb_palette_5 = vb:row{
    style = "panel",
    vb:text{ text="replicate:", style="strong" },
    vb:text{ text="row", style="disabled" },
    expand_row_box,
    vb:button{ text="Expand",  width=80, notifier=function()
      PakettiGroovebox8120ExpandSelectionReplicate(expand_row_box.value)
    end },
    vb:button{ text="Shrink",  width=80, notifier=function()
      PakettiGroovebox8120ShrinkSelectionReplicate(expand_row_box.value)
    end },
  }

  local body = vb:row{
    vb:column(left_col),
    cv_canvas,
    vb:column(right_col),
  }

  local status = vb:row{
    style = "panel",
    u.selection_label,
    vb:text{ text="  ·  click cell · drag = range · alt+click = quadrant · shift+click = extend",
      style="disabled" },
  }

  cv_ui = u
  return vb:column{
    margin = 6, spacing = 4,
    transport_bar,
    verb_palette_1,
    verb_palette_2,
    verb_palette_3,
    verb_palette_4,
    verb_palette_5,
    body,
    status,
  }
end

function PakettiEightOneTwentyCanvasViewShow()
  if cv_dialog and cv_dialog.visible then
    cv_dialog:close()
    cv_dialog = nil
    return
  end
  -- Classic 8120 dialog must exist for rows[] to be populated.
  if not (dialog and dialog.visible) then
    pakettiEightSlotsByOneTwentyDialog()
  end
  cv_selection = nil
  local content = cv_build_view()
  cv_update_selection_label()
  cv_dialog = renoise.app():show_custom_dialog("Paketti Groovebox 8120 — Canvas View (MK2)", content)
end

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:Groovebox:Canvas View (MK2)…",
  invoke = PakettiEightOneTwentyCanvasViewShow }
PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Groovebox 8120 Canvas View (MK2)…",
  invoke = PakettiEightOneTwentyCanvasViewShow }

renoise.tool():add_keybinding{
  name = "Global:Paketti:Paketti Groovebox 8120 Canvas View",
  invoke = PakettiEightOneTwentyCanvasViewShow }
renoise.tool():add_midi_mapping{
  name = "Paketti:Paketti Groovebox 8120:Canvas View [Trigger]",
  invoke = function(m) if m:is_trigger() then PakettiEightOneTwentyCanvasViewShow() end end }

end -- if PAKETTI_HAS_CANVAS
