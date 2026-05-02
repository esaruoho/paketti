-- PakettiSidechainDoofer.lua
-- Sidechain Doofer infrastructure: trigger instrument generator, doofer
-- auto-loader, (future) trigger column mirror. Supports the Mr. Zensphere–style
-- sidechain workflow (Key Tracker → Custom LFO → Compressor) and any
-- rhythm-locked parameter modulation built on top of it.
--
-- Ships:
--   • PakettiCreateTriggerInstrument(name)
--   • PakettiInsertSidechainDoofer(opts)
--   • PakettiSidechainDooferShowDialog()
-- Planned: trigger column mirror, velocity-sensitive variant, recipe save/load.

------------------------------------------------------------------------
-- Standardized Macro Names (used by all auto-loaded sidechain instances)
------------------------------------------------------------------------
-- Same order, same names, on every Doofer Paketti spawns. Build muscle memory.

PakettiSidechainDooferMacroNames = {
  "Threshold",   -- 1 — compressor threshold (LFO-driven, but exposed to user too)
  "Ratio",       -- 2 — compressor ratio
  "Attack",      -- 3 — compressor attack
  "Release",     -- 4 — compressor release
  "Makeup",      -- 5 — compressor make-up gain
  "Lines/Cycle", -- 6 — LFO frequency expressed as lines per cycle
  "Amount",      -- 7 — LFO amplitude (depth of ducking)
  "Offset"       -- 8 — LFO offset (vertical baseline)
}

------------------------------------------------------------------------
-- Trigger Instrument Generator
------------------------------------------------------------------------
-- Creates a silent MIDI-trigger instrument matching the spec from the
-- Mr. Zensphere sidechain video: a single zero-amplitude mono sample,
-- velocity→volume disabled, key→pitch disabled, no loop, volume at -INF.
-- The instrument exists only to emit note events that drive a Key Tracker
-- inside a Sidechain Doofer; it produces no sound.
--
-- If an instrument with the requested name already exists, selects it
-- instead of creating a duplicate.

function PakettiCreateTriggerInstrument(name)
  name = name or "trigger"

  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return nil
  end

  -- Reuse existing trigger instrument by name if present
  for i, instr in ipairs(song.instruments) do
    if instr.name == name then
      song.selected_instrument_index = i
      renoise.app():show_status("Selected existing '" .. name .. "' instrument at slot " .. string.format("%02X", i - 1))
      return instr
    end
  end

  song:describe_undo("Paketti: Create Trigger Instrument '" .. name .. "'")

  -- Insert after currently selected instrument
  local insert_index = song.selected_instrument_index + 1
  local instr = safeInsertInstrumentAt(song, insert_index)
  if not instr then
    return nil
  end

  instr.name = name

  -- Make sure the instrument has at least one sample slot
  if #instr.samples == 0 then
    instr:insert_sample_at(1)
  end

  local sample = instr.samples[1]

  -- Create a tiny silent buffer (8 frames of zero, mono, 16-bit, 44100 Hz)
  local buf = sample.sample_buffer
  buf:create_sample_data(44100, 16, 1, 8)
  buf:prepare_sample_data_changes()
  for f = 1, 8 do
    buf:set_sample_data(1, f, 0.0)
  end
  buf:finalize_sample_data_changes()

  -- Sample-level settings: silent, no loop
  sample.name = name
  sample.volume = 0.0                                    -- -INF dB
  sample.loop_mode = renoise.Sample.LOOP_MODE_OFF

  -- Mapping: full velocity range, full key range, no vel→vol, no key→pitch
  -- so every triggered note arrives at the Key Tracker identically
  local mapping = sample.sample_mapping
  mapping.map_velocity_to_volume = false
  mapping.map_key_to_pitch = false
  mapping.velocity_range = {0, 127}
  mapping.note_range = {0, 119}

  -- Select the new instrument so the user sees what just happened
  song.selected_instrument_index = insert_index

  renoise.app():show_status("Created trigger instrument '" .. name .. "' at slot " .. string.format("%02X", insert_index - 1))
  return instr
end

------------------------------------------------------------------------
-- Sidechain Doofer Auto-Loader
------------------------------------------------------------------------
-- Drops Key Tracker → *LFO → Compressor on the selected track, wires the
-- Key Tracker to reset the LFO on every note from the chosen trigger
-- instrument, wires the LFO to drive the compressor's threshold, and
-- pre-applies a default ducking curve (EDM Pump). Sets sane sidechain
-- compressor defaults (ratio 4:1, attack 1ms, release ~80ms).
--
-- opts (table, all optional):
--   instrument_index  — 1-based instrument index for the Key Tracker filter
--                       (default: first instrument named "trigger" if present,
--                        otherwise the currently selected instrument)
--   curve             — name in PakettiAutomationCurvesShapes (default "edmPump")
--   lines_per_cycle   — LFO cycle length in lines (default 16)
--   envelope_length   — LFO custom envelope length (default 64)

local function find_param_by_name(device, ...)
  local names = {...}
  for i, p in ipairs(device.parameters) do
    for _, n in ipairs(names) do
      if p.name == n then return i, p end
    end
  end
  return nil, nil
end

local function lines_per_cycle_to_freq_normalized(lines)
  -- *LFO Frequency parameter is normalized 0–1, mapped to a wide range.
  -- Empirically: lines/cycle ≈ 1024 / 2^(freq*10). Default 16 lpc.
  -- Safer: just store the parameter value derived from log mapping.
  -- Renoise LFO Frequency parameter accepts 0..1 and the displayed value
  -- shows lines per cycle. We'll set parameter via .value directly using
  -- the value-to-string round-trip later if needed.
  -- For now we just clamp lines to a sensible range.
  return math.max(1, math.min(1024, lines))
end

local function find_trigger_instrument_index()
  local song = renoise.song()
  if not song then return nil end
  for i, instr in ipairs(song.instruments) do
    local n = instr.name
    if n == "trigger"
       or n == "Kick Trigger"
       or n == "Snare Trigger"
       or n == "Hat Trigger" then
      return i
    end
  end
  return nil
end

function PakettiInsertSidechainDoofer(opts)
  opts = opts or {}
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return nil
  end

  local track = song.selected_track
  if not track or track.type == renoise.Track.TRACK_TYPE_MASTER
     or track.type == renoise.Track.TRACK_TYPE_SEND then
    renoise.app():show_status("Sidechain Doofer needs a regular sequencer or group track selected")
    return nil
  end

  local instrument_index = opts.instrument_index
                        or find_trigger_instrument_index()
                        or song.selected_instrument_index
  local curve_name = opts.curve or "edmPump"
  local lines_per_cycle = opts.lines_per_cycle or 16
  local envelope_length = opts.envelope_length or 64

  song:describe_undo("Paketti: Insert Sidechain Doofer")

  -- 1. Insert devices at end of track DSP chain
  local insert_pos = #track.devices + 1
  local kt_dev = track:insert_device_at("Audio/Effects/Native/*Key Tracker", insert_pos)
  local lfo_dev = track:insert_device_at("Audio/Effects/Native/*LFO", insert_pos + 1)
  local comp_dev = track:insert_device_at("Audio/Effects/Native/Compressor", insert_pos + 2)

  kt_dev.display_name = "Sidechain Trigger"
  lfo_dev.display_name = "Sidechain Curve"
  comp_dev.display_name = "Sidechain Compressor"

  -- 2. Compressor sane sidechain defaults (find params by name; fall back to indices)
  do
    local _, p_thresh = find_param_by_name(comp_dev, "Threshold", "Thresh")
    local _, p_ratio  = find_param_by_name(comp_dev, "Ratio")
    local _, p_attack = find_param_by_name(comp_dev, "Attack")
    local _, p_rel    = find_param_by_name(comp_dev, "Release")
    local _, p_makeup = find_param_by_name(comp_dev, "Make-Up", "MakeUp", "Makeup", "Gain")

    if p_thresh then p_thresh.value = p_thresh.value_max end             -- 0 dB initial; LFO will pull down
    if p_ratio  then p_ratio.value  = p_ratio.value_min  + (p_ratio.value_max - p_ratio.value_min) * 0.45 end -- ~4:1ish
    if p_attack then p_attack.value = p_attack.value_min + (p_attack.value_max - p_attack.value_min) * 0.05 end -- fast
    if p_rel    then p_rel.value    = p_rel.value_min    + (p_rel.value_max    - p_rel.value_min)    * 0.30 end -- ~80ms-ish

    -- Expose to the mixer for visibility
    if p_thresh then p_thresh.show_in_mixer = true end
    if p_ratio  then p_ratio.show_in_mixer  = true end
    if p_attack then p_attack.show_in_mixer = true end
    if p_rel    then p_rel.show_in_mixer    = true end
    if p_makeup then p_makeup.show_in_mixer = true end
  end

  -- 3. Wire Key Tracker → LFO Reset
  -- *Key Tracker param layout (Renoise native):
  --   1 Dest. Track   2 Dest. Effect   3 Dest. Parameter
  --   4 Min   5 Max   6 Mode   ...   Linked Instrument
  do
    -- Dest. Effect: device index of the LFO within this track (0-based in the parameter)
    local _, p_dest_effect = find_param_by_name(kt_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(kt_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_min         = find_param_by_name(kt_dev, "Min")
    local _, p_max         = find_param_by_name(kt_dev, "Max")
    local _, p_linked      = find_param_by_name(kt_dev, "Linked Instrument", "LinkedInstrument", "Instr.", "Instrument")

    -- Find the LFO's "Reset" parameter index (this is what we want Key Tracker to drive)
    local lfo_reset_param_idx = select(1, find_param_by_name(lfo_dev, "Reset"))

    -- Find the LFO's track-position index (0-based)
    local lfo_track_idx_zero_based = nil
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then
        lfo_track_idx_zero_based = i - 1
        break
      end
    end

    if p_dest_effect and lfo_track_idx_zero_based then
      p_dest_effect.value = lfo_track_idx_zero_based
    end
    if p_dest_param and lfo_reset_param_idx then
      -- The "Dest. Parameter" parameter is 0-based; lfo_reset_param_idx is 1-based
      p_dest_param.value = lfo_reset_param_idx - 1
    end
    -- Any incoming note resets LFO to position 0
    if p_min then p_min.value = 0 end
    if p_max then p_max.value = 0 end
    -- Filter to chosen instrument (1-based in our code → device parameter is 1-based instrument idx)
    if p_linked and instrument_index then
      -- Some Renoise versions expose this as 0-based, others as 1-based. Try 1-based first.
      local target = instrument_index
      if target >= p_linked.value_min and target <= p_linked.value_max then
        p_linked.value = target
      end
    end

    if p_dest_effect then p_dest_effect.show_in_mixer = true end
    if p_dest_param then p_dest_param.show_in_mixer = true end
    if p_linked then p_linked.show_in_mixer = true end
  end

  -- 4. Wire LFO → Compressor Threshold and set up Custom mode
  -- *LFO param layout: 1 Dest. Track  2 Dest. Effect  3 Dest. Parameter
  --                    4 Amplitude    5 Offset        6 Frequency
  --                    7 Type          8 Phase ...    + Reset
  do
    local _, p_dest_effect = find_param_by_name(lfo_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(lfo_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_amplitude   = find_param_by_name(lfo_dev, "Amplitude")
    local _, p_offset      = find_param_by_name(lfo_dev, "Offset")
    local _, p_frequency   = find_param_by_name(lfo_dev, "Frequency")
    local _, p_type        = find_param_by_name(lfo_dev, "Type")

    -- Find compressor track-index (0-based)
    local comp_track_idx_zero_based = nil
    for i = 1, #track.devices do
      if rawequal(track.devices[i], comp_dev) then
        comp_track_idx_zero_based = i - 1
        break
      end
    end

    -- Find compressor "Threshold" parameter index (1-based)
    local comp_thresh_idx = select(1, find_param_by_name(comp_dev, "Threshold", "Thresh"))

    if p_dest_effect and comp_track_idx_zero_based then
      p_dest_effect.value = comp_track_idx_zero_based
    end
    if p_dest_param and comp_thresh_idx then
      p_dest_param.value = comp_thresh_idx - 1
    end

    -- Amplitude full scale → maximum ducking depth
    if p_amplitude then p_amplitude.value = p_amplitude.value_max end
    -- Offset baseline → highest (compressor sits at threshold ceiling, LFO pulls down)
    if p_offset then p_offset.value = p_offset.value_max end

    -- Type to Custom (4)
    if p_type then
      p_type.value = math.min(p_type.value_max, 4)
    end

    -- Frequency: clamp lines/cycle to range. The LFO frequency parameter
    -- maps complexly; we leave it at default and let the curve writer
    -- (PakettiAutomationCurvesWriteToLFOCustom) drive envelope_length.
    -- The actual lines/cycle is governed by the envelope_length and
    -- LFO timebase; the user can adjust via the LFO UI afterwards.

    if p_dest_effect then p_dest_effect.show_in_mixer = true end
    if p_dest_param  then p_dest_param.show_in_mixer  = true end
    if p_amplitude   then p_amplitude.show_in_mixer   = true end
    if p_offset      then p_offset.show_in_mixer      = true end
    if p_frequency   then p_frequency.show_in_mixer   = true end
  end

  -- 5. Apply default ducking curve via existing PakettiAutomationCurves writer.
  -- This selects the LFO device and calls the writer.
  do
    -- Make sure shapes are initialized (sidechain pack may not have run yet on first invocation)
    if not PakettiAutomationCurvesShapes and PakettiAutomationCurvesInitShapes then
      PakettiAutomationCurvesInitShapes()
    end
    if PakettiSidechainCurvesInject then
      PakettiSidechainCurvesInject()
    end

    if PakettiAutomationCurvesWriteToLFOCustom and
       PakettiAutomationCurvesShapes and
       PakettiAutomationCurvesShapes[curve_name] then
      song.selected_track_index = song.selected_track_index  -- noop, ensures track context
      -- Select the LFO device so the writer targets it
      local prev_device_index = song.selected_track.devices[1] and 1 or 1
      for i = 1, #track.devices do
        if rawequal(track.devices[i], lfo_dev) then
          song.selected_device_index = i
          break
        end
      end
      PakettiAutomationCurvesLFOEnvelopeLength = envelope_length
      PakettiAutomationCurvesWriteToLFOCustom(curve_name)
    end
  end

  -- 6. Optional: insert *Velocity Tracker before the LFO for velocity-sensitive duck depth
  --    Velocity Tracker → LFO Amplitude. Soft kicks duck softly, hard kicks slam.
  if opts.velocity_sensitive then
    local vt_pos = nil
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then vt_pos = i; break end
    end
    if vt_pos then
      local vt_dev = track:insert_device_at("Audio/Effects/Native/*Velocity Tracker", vt_pos)
      vt_dev.display_name = "Sidechain Velocity"

      -- Re-find LFO position after insertion
      local lfo_track_idx_zero_based = nil
      for i = 1, #track.devices do
        if rawequal(track.devices[i], lfo_dev) then
          lfo_track_idx_zero_based = i - 1
          break
        end
      end

      -- Find LFO Amplitude param index
      local lfo_amp_idx = select(1, find_param_by_name(lfo_dev, "Amplitude"))

      local _, p_dest_effect = find_param_by_name(vt_dev, "Dest. Effect", "Dest Effect")
      local _, p_dest_param  = find_param_by_name(vt_dev, "Dest. Parameter", "Dest Parameter")
      local _, p_min         = find_param_by_name(vt_dev, "Min")
      local _, p_max         = find_param_by_name(vt_dev, "Max")
      local _, p_linked      = find_param_by_name(vt_dev, "Linked Instrument", "LinkedInstrument", "Instr.", "Instrument")

      if p_dest_effect and lfo_track_idx_zero_based then p_dest_effect.value = lfo_track_idx_zero_based end
      if p_dest_param and lfo_amp_idx then p_dest_param.value = lfo_amp_idx - 1 end
      if p_min then p_min.value = p_min.value_min end
      if p_max then p_max.value = p_max.value_max end
      if p_linked and instrument_index and instrument_index >= p_linked.value_min and instrument_index <= p_linked.value_max then
        p_linked.value = instrument_index
      end
    end
  end

  -- 7. Select the Key Tracker so the user lands on the head of the chain
  for i = 1, #track.devices do
    if rawequal(track.devices[i], kt_dev) then
      song.selected_device_index = i
      break
    end
  end

  local instr_label = (song.instruments[instrument_index] and song.instruments[instrument_index].name) or "?"
  local curve_label = (PakettiAutomationCurvesShapes
                       and PakettiAutomationCurvesShapes[curve_name]
                       and PakettiAutomationCurvesShapes[curve_name].label) or curve_name
  renoise.app():show_status(string.format(
    "Sidechain Doofer inserted on '%s' — trigger='%s' (slot %02X), curve='%s'",
    track.name, instr_label,
    instrument_index and (instrument_index - 1) or 0,
    curve_label))
  return kt_dev, lfo_dev, comp_dev
end

------------------------------------------------------------------------
-- Sidechain Doofer Auto-Loader Dialog
------------------------------------------------------------------------

PakettiSidechainDooferDialog = nil

function PakettiSidechainDooferShowDialog()
  if PakettiSidechainDooferDialog and PakettiSidechainDooferDialog.visible then
    PakettiSidechainDooferDialog:close()
    PakettiSidechainDooferDialog = nil
    return
  end

  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end

  -- Make sure shapes are loaded
  if not PakettiAutomationCurvesShapes and PakettiAutomationCurvesInitShapes then
    PakettiAutomationCurvesInitShapes()
  end
  if PakettiSidechainCurvesInject then
    PakettiSidechainCurvesInject()
  end

  -- Build instrument popup items
  local instr_items = {}
  for i, instr in ipairs(song.instruments) do
    table.insert(instr_items, string.format("%02X: %s", i - 1, instr.name ~= "" and instr.name or "<unnamed>"))
  end
  if #instr_items == 0 then
    table.insert(instr_items, "<no instruments>")
  end

  local default_instr_idx = find_trigger_instrument_index() or song.selected_instrument_index
  if default_instr_idx > #instr_items then default_instr_idx = 1 end

  -- Build curve popup items in a sensible sidechain order
  local sidechain_curves = {
    "edmPump", "reversePump", "doubleTap", "tripleTap",
    "kickGhost", "bumpPump", "breathPump", "swingDuck",
    "rampDown", "bellDown", "sCurveDown", "cosDown"
  }
  local curve_labels = {}
  local curve_keys = {}
  for _, k in ipairs(sidechain_curves) do
    if PakettiAutomationCurvesShapes and PakettiAutomationCurvesShapes[k] then
      table.insert(curve_keys, k)
      table.insert(curve_labels, PakettiAutomationCurvesShapes[k].label or k)
    end
  end

  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10,
    spacing = 6,

    vb:text{text = "Insert Sidechain Doofer on selected track", style = "strong"},
    vb:text{text = "Inserts: *Key Tracker → *LFO → Compressor", style = "disabled"},

    vb:row{
      vb:text{text = "Trigger instrument:", width = 130},
      vb:popup{
        id = "instr_popup",
        items = instr_items,
        value = default_instr_idx,
        width = 280
      }
    },

    vb:row{
      vb:text{text = "Default curve:", width = 130},
      vb:popup{
        id = "curve_popup",
        items = curve_labels,
        value = 1,
        width = 280
      }
    },

    vb:row{
      vb:text{text = "Envelope length:", width = 130},
      vb:popup{
        id = "env_popup",
        items = {"64", "128", "256", "512", "1024"},
        value = 1,
        width = 80
      }
    },

    vb:row{
      vb:text{text = "Lines per cycle:", width = 130},
      vb:valuebox{
        id = "lpc_box",
        min = 1,
        max = 1024,
        value = 16,
        width = 80
      }
    },

    vb:row{
      vb:text{text = "Velocity-sensitive:", width = 130},
      vb:checkbox{
        id = "vel_check",
        value = false
      },
      vb:text{text = "  (adds *Velocity Tracker → LFO Amplitude)", style = "disabled"}
    },

    vb:row{
      spacing = 6,
      vb:button{
        text = "Insert",
        width = 110,
        notifier = function()
          local env_lengths = {64, 128, 256, 512, 1024}
          PakettiInsertSidechainDoofer{
            instrument_index = vb.views.instr_popup.value,
            curve = curve_keys[vb.views.curve_popup.value] or "edmPump",
            envelope_length = env_lengths[vb.views.env_popup.value] or 64,
            lines_per_cycle = vb.views.lpc_box.value,
            velocity_sensitive = vb.views.vel_check.value
          }
        end
      },
      vb:button{
        text = "Insert + close",
        width = 110,
        notifier = function()
          local env_lengths = {64, 128, 256, 512, 1024}
          PakettiInsertSidechainDoofer{
            instrument_index = vb.views.instr_popup.value,
            curve = curve_keys[vb.views.curve_popup.value] or "edmPump",
            envelope_length = env_lengths[vb.views.env_popup.value] or 64,
            lines_per_cycle = vb.views.lpc_box.value,
            velocity_sensitive = vb.views.vel_check.value
          }
          if PakettiSidechainDooferDialog and PakettiSidechainDooferDialog.visible then
            PakettiSidechainDooferDialog:close()
            PakettiSidechainDooferDialog = nil
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          if PakettiSidechainDooferDialog and PakettiSidechainDooferDialog.visible then
            PakettiSidechainDooferDialog:close()
            PakettiSidechainDooferDialog = nil
          end
        end
      }
    }
  }

  PakettiSidechainDooferDialog = renoise.app():show_custom_dialog(
    "Paketti: Sidechain Doofer Auto-Loader", content)
end

------------------------------------------------------------------------
-- Trigger Column Mirror
------------------------------------------------------------------------
-- Mirrors note positions from a source track's note column N to a target
-- track's note column M, writing the chosen trigger instrument at every
-- source hit. Optionally renames the target column "trigger" (column tagging).
--
-- opts:
--   source_track_index, source_column_index   (1-based)
--   target_track_index, target_column_index   (1-based)
--   trigger_instrument_index                  (1-based)
--   scope            "current_pattern" | "all_patterns"
--   every_n          1=every hit, 2=every other, etc.   (default 1)
--   min_velocity     0..127, only mirror hits ≥ this    (default 0)
--   beats_filter     {true,true,true,true} for 4/4 beats; nil = no filter
--   tag_column       boolean — set target column name to "trigger" (default true)

local function get_track_pattern_track(pattern, track_index)
  return pattern:track(track_index)
end

function PakettiSidechainMirrorTriggers(opts)
  opts = opts or {}
  local song = renoise.song()
  if not song then
    renoise.app():show_status("No song loaded")
    return
  end

  local source_track_idx  = opts.source_track_index  or song.selected_track_index
  local source_col_idx    = opts.source_column_index or 1
  local target_track_idx  = opts.target_track_index  or song.selected_track_index
  local target_col_idx    = opts.target_column_index or 2
  local trig_idx          = opts.trigger_instrument_index or find_trigger_instrument_index() or 1
  local scope             = opts.scope or "current_pattern"
  local every_n           = math.max(1, opts.every_n or 1)
  local min_velocity      = math.max(0, math.min(127, opts.min_velocity or 0))
  local beats_filter      = opts.beats_filter   -- nil or array of booleans
  local tag_column        = (opts.tag_column ~= false)

  local source_track = song.tracks[source_track_idx]
  local target_track = song.tracks[target_track_idx]
  if not source_track or not target_track then
    renoise.app():show_status("Source/target track invalid")
    return
  end

  -- Make sure target column is visible
  if target_col_idx > target_track.visible_note_columns then
    target_track.visible_note_columns = math.min(12, math.max(target_track.visible_note_columns, target_col_idx))
  end

  -- Tag the target column (visual)
  if tag_column then
    pcall(function() target_track:set_column_name(target_col_idx, "trigger") end)
  end

  song:describe_undo("Paketti: Mirror Trigger Notes")

  local lpb = song.transport.lpb

  local function process_pattern(pattern_index)
    local pattern = song.patterns[pattern_index]
    if not pattern then return 0 end
    local src_pt = pattern:track(source_track_idx)
    local tgt_pt = pattern:track(target_track_idx)
    if not src_pt or not tgt_pt then return 0 end

    local hit_count = 0
    local kept_count = 0
    for line_idx = 1, pattern.number_of_lines do
      local src_line = src_pt:line(line_idx)
      local src_col  = src_line.note_columns[source_col_idx]
      local has_note = src_col and not src_col.is_empty
                        and src_col.note_value < renoise.PatternLine.NOTE_OFF
      if has_note then
        hit_count = hit_count + 1
        local pass_n = ((hit_count - 1) % every_n == 0)
        local pass_v = (src_col.volume_value == 255) -- "empty" volume slot = full
                        or (src_col.volume_value >= min_velocity)
        local pass_b = true
        if beats_filter then
          local beat_idx = math.floor((line_idx - 1) / lpb) % #beats_filter + 1
          pass_b = beats_filter[beat_idx] == true
        end

        if pass_n and pass_v and pass_b then
          local tgt_line = tgt_pt:line(line_idx)
          local tgt_col = tgt_line.note_columns[target_col_idx]
          if tgt_col then
            tgt_col.note_value = (src_col.note_value < 120) and src_col.note_value or 48 -- C-4 default
            tgt_col.instrument_value = trig_idx - 1
            -- Preserve velocity if source had explicit volume
            if src_col.volume_value ~= 255 then
              tgt_col.volume_value = src_col.volume_value
            end
            -- Preserve delay column for sub-line accuracy
            tgt_col.delay_value = src_col.delay_value
            kept_count = kept_count + 1
          end
        end
      end
    end
    return kept_count
  end

  local total = 0
  if scope == "all_patterns" then
    for i = 1, #song.patterns do
      total = total + process_pattern(i)
    end
  else
    total = process_pattern(song.selected_pattern_index)
  end

  renoise.app():show_status(string.format(
    "Mirrored %d trigger note(s) — %s col %d → %s col %d (instr %02X)",
    total,
    source_track.name, source_col_idx,
    target_track.name, target_col_idx,
    trig_idx - 1))
end

------------------------------------------------------------------------
-- Trigger Column Mirror Dialog
------------------------------------------------------------------------

PakettiSidechainMirrorDialog = nil

function PakettiSidechainMirrorShowDialog()
  if PakettiSidechainMirrorDialog and PakettiSidechainMirrorDialog.visible then
    PakettiSidechainMirrorDialog:close()
    PakettiSidechainMirrorDialog = nil
    return
  end

  local song = renoise.song()
  if not song then return end

  local track_items = {}
  for i, t in ipairs(song.tracks) do
    table.insert(track_items, string.format("%02d: %s", i, t.name ~= "" and t.name or "<unnamed>"))
  end

  local instr_items = {}
  for i, instr in ipairs(song.instruments) do
    table.insert(instr_items, string.format("%02X: %s", i - 1, instr.name ~= "" and instr.name or "<unnamed>"))
  end
  local default_trig = find_trigger_instrument_index() or 1

  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10,
    spacing = 6,

    vb:text{text = "Mirror notes from a source column → trigger notes in a target column", style = "strong"},

    vb:row{
      vb:text{text = "Source track:", width = 110},
      vb:popup{id = "src_track", items = track_items, value = song.selected_track_index, width = 280}
    },
    vb:row{
      vb:text{text = "Source column:", width = 110},
      vb:valuebox{id = "src_col", min = 1, max = 12, value = 1, width = 60}
    },
    vb:row{
      vb:text{text = "Target track:", width = 110},
      vb:popup{id = "tgt_track", items = track_items, value = song.selected_track_index, width = 280}
    },
    vb:row{
      vb:text{text = "Target column:", width = 110},
      vb:valuebox{id = "tgt_col", min = 1, max = 12, value = 2, width = 60}
    },
    vb:row{
      vb:text{text = "Trigger instrument:", width = 110},
      vb:popup{id = "trig", items = #instr_items > 0 and instr_items or {"<none>"}, value = default_trig, width = 280}
    },
    vb:row{
      vb:text{text = "Scope:", width = 110},
      vb:popup{id = "scope", items = {"Current pattern", "All patterns"}, value = 1, width = 200}
    },
    vb:row{
      vb:text{text = "Every Nth hit:", width = 110},
      vb:valuebox{id = "every_n", min = 1, max = 16, value = 1, width = 60}
    },
    vb:row{
      vb:text{text = "Min velocity:", width = 110},
      vb:valuebox{id = "min_vel", min = 0, max = 127, value = 0, width = 60}
    },
    vb:row{
      vb:text{text = "Tag target column 'trigger':", width = 200},
      vb:checkbox{id = "tag_col", value = true}
    },

    vb:row{
      spacing = 6,
      vb:button{
        text = "Mirror",
        width = 110,
        notifier = function()
          PakettiSidechainMirrorTriggers{
            source_track_index = vb.views.src_track.value,
            source_column_index = vb.views.src_col.value,
            target_track_index = vb.views.tgt_track.value,
            target_column_index = vb.views.tgt_col.value,
            trigger_instrument_index = vb.views.trig.value,
            scope = vb.views.scope.value == 2 and "all_patterns" or "current_pattern",
            every_n = vb.views.every_n.value,
            min_velocity = vb.views.min_vel.value,
            tag_column = vb.views.tag_col.value
          }
        end
      },
      vb:button{
        text = "Close",
        width = 80,
        notifier = function()
          if PakettiSidechainMirrorDialog and PakettiSidechainMirrorDialog.visible then
            PakettiSidechainMirrorDialog:close()
            PakettiSidechainMirrorDialog = nil
          end
        end
      }
    }
  }

  PakettiSidechainMirrorDialog = renoise.app():show_custom_dialog(
    "Paketti: Trigger Column Mirror", content)
end

------------------------------------------------------------------------
-- Column Tagging — manual helper
------------------------------------------------------------------------
-- Tags the currently selected note column on the selected track as "trigger"
-- so users can see at a glance which columns are sidechain triggers.

function PakettiSidechainTagSelectedColumn(label)
  label = label or "trigger"
  local song = renoise.song()
  local track = song and song.selected_track
  local col_idx = song and song.selected_note_column_index
  if not track or not col_idx or col_idx < 1 then
    renoise.app():show_status("Select a note column to tag")
    return
  end
  local ok, err = pcall(function() track:set_column_name(col_idx, label) end)
  if ok then
    renoise.app():show_status("Tagged column " .. col_idx .. " as '" .. label .. "'")
  else
    renoise.app():show_status("Could not tag column: " .. tostring(err))
  end
end

------------------------------------------------------------------------
-- Trigger Phrase Library
------------------------------------------------------------------------
-- Generates a library of pre-named phrases inside the chosen trigger
-- instrument: reusable rhythmic ducking patterns. Drop a phrase trigger
-- in the pattern instead of placing notes by hand.
--
-- Each phrase emits the same C-4 note (will hit Key Tracker filter)
-- at the chosen rhythmic positions, with full velocity.

local PAKETTI_SIDECHAIN_TRIGGER_PHRASES = {
  {name = "4-on-floor",  lpb = 4, lines = 16, hits = {1, 5, 9, 13}},
  {name = "Half-time",   lpb = 4, lines = 16, hits = {1, 9}},
  {name = "8th-gate",    lpb = 4, lines = 16, hits = {1, 3, 5, 7, 9, 11, 13, 15}},
  {name = "16th-gate",   lpb = 4, lines = 16, hits = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}},
  {name = "Trance gate", lpb = 4, lines = 16, hits = {1, 3, 5, 7, 9, 11, 13, 15}}, -- 8ths classic
  {name = "Dub-stab",    lpb = 4, lines = 16, hits = {1, 7, 11}},
  {name = "Garage swing",lpb = 4, lines = 16, hits = {1, 4, 7, 11, 13}},
  {name = "Beats 1+3",   lpb = 4, lines = 16, hits = {1, 9}},
  {name = "Beats 2+4",   lpb = 4, lines = 16, hits = {5, 13}},
  {name = "Off-beats",   lpb = 4, lines = 16, hits = {3, 7, 11, 15}},
  {name = "Triplet 8ths",lpb = 6, lines = 24, hits = {1, 4, 7, 10, 13, 16, 19, 22}},
  {name = "Build-up",    lpb = 4, lines = 16, hits = {1, 9, 13, 15, 16}}
}

function PakettiSidechainGenerateTriggerPhrases(instr_index)
  local song = renoise.song()
  if not song then return end

  instr_index = instr_index or find_trigger_instrument_index() or song.selected_instrument_index
  local instr = song.instruments[instr_index]
  if not instr then
    renoise.app():show_status("No instrument at index " .. tostring(instr_index))
    return
  end

  song:describe_undo("Paketti: Generate Trigger Phrase Library")

  local existing_names = {}
  for _, ph in ipairs(instr.phrases) do existing_names[ph.name] = true end

  local added = 0
  for _, def in ipairs(PAKETTI_SIDECHAIN_TRIGGER_PHRASES) do
    local pname = "SC: " .. def.name
    if not existing_names[pname] then
      local insert_idx = #instr.phrases + 1
      if insert_idx > 126 then
        renoise.app():show_status("Phrase limit reached (126) — stopped at " .. added)
        return
      end
      local ph = instr:insert_phrase_at(insert_idx)
      ph.name = pname
      ph.lpb = def.lpb
      ph.number_of_lines = def.lines
      for _, line_idx in ipairs(def.hits) do
        if line_idx <= def.lines then
          local col = ph.lines[line_idx].note_columns[1]
          col.note_value = 48           -- C-4
          col.instrument_value = instr_index - 1
          col.volume_value = 127         -- full velocity
        end
      end
      added = added + 1
    end
  end

  renoise.app():show_status(string.format(
    "Added %d trigger phrases to '%s' (skipped duplicates)",
    added, instr.name))
end

------------------------------------------------------------------------
-- Sidechain Recipe Save / Load
------------------------------------------------------------------------
-- A "recipe" is the active_preset_data of the 3 sidechain devices
-- (Key Tracker / *LFO / Compressor) on the selected track, plus their
-- display names, saved to a single XML wrapper file. Reload writes the
-- preset data back onto the matching devices on the selected track.

local function paketti_sidechain_recipes_dir()
  local base = renoise.tool().bundle_path .. "Presets/SidechainRecipes/"
  -- Best-effort directory creation on macOS/Linux/Windows
  os.execute('mkdir -p "' .. base .. '" 2>/dev/null')
  return base
end

local function find_sidechain_devices_on_track(track)
  local kt, lfo, comp, vt
  for _, d in ipairs(track.devices) do
    local n = d.name
    local dn = d.display_name or ""
    if n == "*Key Tracker" and (dn == "" or dn:find("Sidechain Trigger") or not kt) then
      kt = kt or d
    elseif n == "*Velocity Tracker" and (dn:find("Sidechain Velocity") or not vt) then
      vt = vt or d
    elseif n == "*LFO" and (dn:find("Sidechain Curve") or not lfo) then
      lfo = lfo or d
    elseif n == "Compressor" and (dn:find("Sidechain Compressor") or not comp) then
      comp = comp or d
    end
  end
  return kt, lfo, comp, vt
end

function PakettiSidechainSaveRecipe(name)
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if not track then return end

  local kt, lfo, comp, vt = find_sidechain_devices_on_track(track)
  if not (kt and lfo and comp) then
    renoise.app():show_status("Selected track has no Sidechain Doofer (need *Key Tracker + *LFO + Compressor)")
    return
  end

  name = name or ("Recipe-" .. os.date("%Y%m%d-%H%M%S"))
  local safe_name = name:gsub("[^%w%-_%. ]", "_")

  local function escape(s)
    return tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  end

  local parts = {}
  table.insert(parts, '<?xml version="1.0" encoding="UTF-8"?>')
  table.insert(parts, '<PakettiSidechainRecipe>')
  table.insert(parts, '  <Name>' .. escape(name) .. '</Name>')
  table.insert(parts, '  <KeyTracker><![CDATA[' .. (kt.active_preset_data or "") .. ']]></KeyTracker>')
  table.insert(parts, '  <Lfo><![CDATA[' .. (lfo.active_preset_data or "") .. ']]></Lfo>')
  table.insert(parts, '  <Compressor><![CDATA[' .. (comp.active_preset_data or "") .. ']]></Compressor>')
  if vt then
    table.insert(parts, '  <VelocityTracker><![CDATA[' .. (vt.active_preset_data or "") .. ']]></VelocityTracker>')
  end
  table.insert(parts, '</PakettiSidechainRecipe>')

  local path = paketti_sidechain_recipes_dir() .. safe_name .. ".xml"
  local f, err = io.open(path, "w")
  if not f then
    renoise.app():show_status("Could not save recipe: " .. tostring(err))
    return
  end
  f:write(table.concat(parts, "\n"))
  f:close()
  renoise.app():show_status("Saved recipe '" .. name .. "' to " .. path)
end

function PakettiSidechainLoadRecipe(path)
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if not track then return end

  local kt, lfo, comp, vt = find_sidechain_devices_on_track(track)
  if not (kt and lfo and comp) then
    renoise.app():show_status("Selected track has no Sidechain Doofer to load into")
    return
  end

  local f, err = io.open(path, "r")
  if not f then
    renoise.app():show_status("Could not open recipe: " .. tostring(err))
    return
  end
  local content = f:read("*all")
  f:close()

  local kt_xml   = content:match("<KeyTracker>%s*<!%[CDATA%[(.-)%]%]>")
  local lfo_xml  = content:match("<Lfo>%s*<!%[CDATA%[(.-)%]%]>")
  local comp_xml = content:match("<Compressor>%s*<!%[CDATA%[(.-)%]%]>")
  local vt_xml   = content:match("<VelocityTracker>%s*<!%[CDATA%[(.-)%]%]>")

  song:describe_undo("Paketti: Load Sidechain Recipe")

  if kt_xml   and kt   then pcall(function() kt.active_preset_data   = kt_xml   end) end
  if lfo_xml  and lfo  then pcall(function() lfo.active_preset_data  = lfo_xml  end) end
  if comp_xml and comp then pcall(function() comp.active_preset_data = comp_xml end) end
  if vt_xml   and vt   then pcall(function() vt.active_preset_data   = vt_xml   end) end

  renoise.app():show_status("Loaded recipe from " .. path)
end

function PakettiSidechainSaveRecipePrompt()
  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "Recipe name:", style = "strong"},
    vb:textfield{id = "name", value = "Verse Pump", width = 240},
    vb:row{
      spacing = 6,
      vb:button{
        text = "Save",
        notifier = function()
          local n = vb.views.name.value
          PakettiSidechainSaveRecipe(n)
          if PakettiSidechainSaveDialog then PakettiSidechainSaveDialog:close() end
          PakettiSidechainSaveDialog = nil
        end
      },
      vb:button{
        text = "Cancel",
        notifier = function()
          if PakettiSidechainSaveDialog then PakettiSidechainSaveDialog:close() end
          PakettiSidechainSaveDialog = nil
        end
      }
    }
  }
  if PakettiSidechainSaveDialog and PakettiSidechainSaveDialog.visible then
    PakettiSidechainSaveDialog:close()
    PakettiSidechainSaveDialog = nil
    return
  end
  PakettiSidechainSaveDialog = renoise.app():show_custom_dialog("Save Sidechain Recipe", content)
end

function PakettiSidechainLoadRecipePrompt()
  local path = renoise.app():prompt_for_filename_to_read({"xml"}, "Load Sidechain Recipe")
  if path and path ~= "" then
    PakettiSidechainLoadRecipe(path)
  end
end

------------------------------------------------------------------------
-- Generic Trigger-Driven Modulator (Sidechain Doofer's bigger sibling)
------------------------------------------------------------------------
-- Same Key Tracker → LFO chassis, but the LFO destination is user-pickable:
-- filter cutoff, send amount, sample offset, anything modulatable on the
-- selected track. No compressor inserted — caller chooses target device.
--
-- opts:
--   instrument_index   — trigger filter (default trigger instrument)
--   target_device_index — 1-based index of an existing device on the track
--   target_param_index  — 1-based parameter index on that device
--   curve              — name in shape registry (default "edmPump")
--   envelope_length    — default 64

function PakettiInsertTriggerDrivenModulator(opts)
  opts = opts or {}
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if not track then return end
  if not opts.target_device_index or not opts.target_param_index then
    renoise.app():show_status("Trigger-Driven Modulator: pick a target device + parameter first")
    return
  end

  local target_dev = track.devices[opts.target_device_index]
  if not target_dev then
    renoise.app():show_status("Target device not found at index " .. opts.target_device_index)
    return
  end

  local instrument_index = opts.instrument_index or find_trigger_instrument_index() or song.selected_instrument_index
  local curve_name = opts.curve or "edmPump"
  local envelope_length = opts.envelope_length or 64

  song:describe_undo("Paketti: Insert Trigger-Driven Modulator")

  local insert_pos = #track.devices + 1
  local kt_dev = track:insert_device_at("Audio/Effects/Native/*Key Tracker", insert_pos)
  local lfo_dev = track:insert_device_at("Audio/Effects/Native/*LFO", insert_pos + 1)

  kt_dev.display_name = "Trigger"
  lfo_dev.display_name = "Trigger Curve"

  -- Wire Key Tracker → LFO Reset
  do
    local _, p_dest_effect = find_param_by_name(kt_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(kt_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_min         = find_param_by_name(kt_dev, "Min")
    local _, p_max         = find_param_by_name(kt_dev, "Max")
    local _, p_linked      = find_param_by_name(kt_dev, "Linked Instrument", "LinkedInstrument", "Instr.", "Instrument")
    local lfo_reset_idx    = select(1, find_param_by_name(lfo_dev, "Reset"))

    local lfo_track_idx_zero_based
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then lfo_track_idx_zero_based = i - 1; break end
    end
    if p_dest_effect and lfo_track_idx_zero_based then p_dest_effect.value = lfo_track_idx_zero_based end
    if p_dest_param and lfo_reset_idx then p_dest_param.value = lfo_reset_idx - 1 end
    if p_min then p_min.value = 0 end
    if p_max then p_max.value = 0 end
    if p_linked and instrument_index >= p_linked.value_min and instrument_index <= p_linked.value_max then
      p_linked.value = instrument_index
    end
  end

  -- Wire LFO → target device + parameter
  do
    local _, p_dest_effect = find_param_by_name(lfo_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(lfo_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_amplitude   = find_param_by_name(lfo_dev, "Amplitude")
    local _, p_offset      = find_param_by_name(lfo_dev, "Offset")
    local _, p_type        = find_param_by_name(lfo_dev, "Type")

    local target_dev_track_idx
    for i = 1, #track.devices do
      if rawequal(track.devices[i], target_dev) then target_dev_track_idx = i - 1; break end
    end
    if p_dest_effect and target_dev_track_idx then p_dest_effect.value = target_dev_track_idx end
    if p_dest_param then p_dest_param.value = opts.target_param_index - 1 end
    if p_amplitude then p_amplitude.value = p_amplitude.value_max end
    if p_offset then p_offset.value = p_offset.value_max end
    if p_type then p_type.value = math.min(p_type.value_max, 4) end
  end

  -- Apply default curve
  if PakettiAutomationCurvesWriteToLFOCustom and PakettiAutomationCurvesShapes
     and PakettiAutomationCurvesShapes[curve_name] then
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then song.selected_device_index = i; break end
    end
    PakettiAutomationCurvesLFOEnvelopeLength = envelope_length
    PakettiAutomationCurvesWriteToLFOCustom(curve_name)
  end

  renoise.app():show_status(string.format(
    "Trigger-Driven Modulator inserted — driving %s param %d (%s)",
    target_dev.name, opts.target_param_index,
    target_dev.parameters[opts.target_param_index] and target_dev.parameters[opts.target_param_index].name or "?"))
  return kt_dev, lfo_dev
end

PakettiTriggerModulatorDialog = nil

function PakettiTriggerModulatorShowDialog()
  if PakettiTriggerModulatorDialog and PakettiTriggerModulatorDialog.visible then
    PakettiTriggerModulatorDialog:close()
    PakettiTriggerModulatorDialog = nil
    return
  end
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if not track then return end

  if not PakettiAutomationCurvesShapes and PakettiAutomationCurvesInitShapes then
    PakettiAutomationCurvesInitShapes()
  end
  if PakettiSidechainCurvesInject then PakettiSidechainCurvesInject() end

  local instr_items = {}
  for i, instr in ipairs(song.instruments) do
    table.insert(instr_items, string.format("%02X: %s", i - 1, instr.name ~= "" and instr.name or "<unnamed>"))
  end
  local default_instr_idx = find_trigger_instrument_index() or song.selected_instrument_index

  local device_items = {}
  for i, d in ipairs(track.devices) do
    table.insert(device_items, string.format("%d: %s", i, d.display_name ~= "" and d.display_name or d.name))
  end

  local sidechain_curves = {
    "edmPump", "reversePump", "doubleTap", "tripleTap",
    "kickGhost", "bumpPump", "breathPump", "swingDuck",
    "rampDown", "bellDown", "sCurveDown", "cosDown"
  }
  local curve_labels, curve_keys = {}, {}
  for _, k in ipairs(sidechain_curves) do
    if PakettiAutomationCurvesShapes and PakettiAutomationCurvesShapes[k] then
      table.insert(curve_keys, k)
      table.insert(curve_labels, PakettiAutomationCurvesShapes[k].label or k)
    end
  end

  local vb = renoise.ViewBuilder()
  -- Build initial param items list for whichever device is initially selected
  local function param_items_for(device_idx)
    local d = track.devices[device_idx]
    local items = {}
    if d then
      for i, p in ipairs(d.parameters) do
        table.insert(items, string.format("%d: %s", i, p.name))
      end
    end
    if #items == 0 then table.insert(items, "<no params>") end
    return items
  end

  local content = vb:column{
    margin = 10, spacing = 6,
    vb:text{text = "Insert Trigger-Driven Modulator on selected track", style = "strong"},
    vb:text{text = "Same chassis as Sidechain Doofer; you pick the target parameter.", style = "disabled"},

    vb:row{
      vb:text{text = "Trigger instrument:", width = 130},
      vb:popup{id = "instr", items = #instr_items > 0 and instr_items or {"<none>"}, value = default_instr_idx, width = 280}
    },
    vb:row{
      vb:text{text = "Target device:", width = 130},
      vb:popup{
        id = "target_device",
        items = #device_items > 0 and device_items or {"<no devices>"},
        value = math.max(1, song.selected_device_index or 1),
        width = 280,
        notifier = function(idx)
          vb.views.target_param.items = param_items_for(idx)
          vb.views.target_param.value = 1
        end
      }
    },
    vb:row{
      vb:text{text = "Target parameter:", width = 130},
      vb:popup{
        id = "target_param",
        items = param_items_for(math.max(1, song.selected_device_index or 1)),
        value = 1,
        width = 280
      }
    },
    vb:row{
      vb:text{text = "Curve:", width = 130},
      vb:popup{id = "curve", items = curve_labels, value = 1, width = 280}
    },
    vb:row{
      vb:text{text = "Envelope length:", width = 130},
      vb:popup{id = "env", items = {"64","128","256","512","1024"}, value = 1, width = 80}
    },
    vb:row{
      spacing = 6,
      vb:button{
        text = "Insert",
        notifier = function()
          local env_lengths = {64,128,256,512,1024}
          PakettiInsertTriggerDrivenModulator{
            instrument_index = vb.views.instr.value,
            target_device_index = vb.views.target_device.value,
            target_param_index = vb.views.target_param.value,
            curve = curve_keys[vb.views.curve.value] or "edmPump",
            envelope_length = env_lengths[vb.views.env.value] or 64
          }
        end
      },
      vb:button{
        text = "Close",
        notifier = function()
          if PakettiTriggerModulatorDialog then PakettiTriggerModulatorDialog:close() end
          PakettiTriggerModulatorDialog = nil
        end
      }
    }
  }
  PakettiTriggerModulatorDialog = renoise.app():show_custom_dialog(
    "Paketti: Trigger-Driven Modulator", content)
end

------------------------------------------------------------------------
-- Hydra Fanout Doofer
------------------------------------------------------------------------
-- Same Key Tracker → LFO chain, but routes the LFO into a *Hydra device
-- whose 9 outputs can each be wired to a different destination.
-- Returns the inserted devices so the user can wire Hydra outputs.

function PakettiInsertSidechainHydraFanout(opts)
  opts = opts or {}
  local song = renoise.song()
  if not song then return end
  local track = song.selected_track
  if not track then return end

  local instrument_index = opts.instrument_index or find_trigger_instrument_index() or song.selected_instrument_index
  local curve_name = opts.curve or "edmPump"
  local envelope_length = opts.envelope_length or 64

  song:describe_undo("Paketti: Insert Sidechain Hydra Fanout")

  local insert_pos = #track.devices + 1
  local kt_dev = track:insert_device_at("Audio/Effects/Native/*Key Tracker", insert_pos)
  local lfo_dev = track:insert_device_at("Audio/Effects/Native/*LFO", insert_pos + 1)
  local hyd_dev = track:insert_device_at("Audio/Effects/Native/*Hydra", insert_pos + 2)

  kt_dev.display_name = "Sidechain Trigger"
  lfo_dev.display_name = "Sidechain Curve"
  hyd_dev.display_name = "Sidechain Fanout"

  -- Wire Key Tracker → LFO Reset
  do
    local _, p_dest_effect = find_param_by_name(kt_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(kt_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_min         = find_param_by_name(kt_dev, "Min")
    local _, p_max         = find_param_by_name(kt_dev, "Max")
    local _, p_linked      = find_param_by_name(kt_dev, "Linked Instrument", "LinkedInstrument", "Instr.", "Instrument")
    local lfo_reset_idx    = select(1, find_param_by_name(lfo_dev, "Reset"))
    local lfo_track_idx
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then lfo_track_idx = i - 1; break end
    end
    if p_dest_effect and lfo_track_idx then p_dest_effect.value = lfo_track_idx end
    if p_dest_param and lfo_reset_idx then p_dest_param.value = lfo_reset_idx - 1 end
    if p_min then p_min.value = 0 end
    if p_max then p_max.value = 0 end
    if p_linked and instrument_index >= p_linked.value_min and instrument_index <= p_linked.value_max then
      p_linked.value = instrument_index
    end
  end

  -- Wire LFO → Hydra Input (parameter 4 typically; find by name)
  do
    local _, p_dest_effect = find_param_by_name(lfo_dev, "Dest. Effect", "Dest Effect")
    local _, p_dest_param  = find_param_by_name(lfo_dev, "Dest. Parameter", "Dest Parameter")
    local _, p_amplitude   = find_param_by_name(lfo_dev, "Amplitude")
    local _, p_offset      = find_param_by_name(lfo_dev, "Offset")
    local _, p_type        = find_param_by_name(lfo_dev, "Type")

    local hyd_track_idx
    for i = 1, #track.devices do
      if rawequal(track.devices[i], hyd_dev) then hyd_track_idx = i - 1; break end
    end
    local hyd_input_idx = select(1, find_param_by_name(hyd_dev, "Input"))

    if p_dest_effect and hyd_track_idx then p_dest_effect.value = hyd_track_idx end
    if p_dest_param and hyd_input_idx then p_dest_param.value = hyd_input_idx - 1 end
    if p_amplitude then p_amplitude.value = p_amplitude.value_max end
    if p_offset then p_offset.value = p_offset.value_max end
    if p_type then p_type.value = math.min(p_type.value_max, 4) end
  end

  if PakettiAutomationCurvesWriteToLFOCustom and PakettiAutomationCurvesShapes
     and PakettiAutomationCurvesShapes[curve_name] then
    for i = 1, #track.devices do
      if rawequal(track.devices[i], lfo_dev) then song.selected_device_index = i; break end
    end
    PakettiAutomationCurvesLFOEnvelopeLength = envelope_length
    PakettiAutomationCurvesWriteToLFOCustom(curve_name)
  end

  -- Land on the Hydra so the user can wire outputs
  for i = 1, #track.devices do
    if rawequal(track.devices[i], hyd_dev) then song.selected_device_index = i; break end
  end

  renoise.app():show_status("Sidechain Hydra Fanout inserted — wire the Hydra's 9 outputs to your destinations")
  return kt_dev, lfo_dev, hyd_dev
end

------------------------------------------------------------------------
-- Sample → Trigger Notes (offline transient capture)
------------------------------------------------------------------------
-- Walks the selected sample's audio buffer in line-sized windows derived
-- from BPM + LPB, peak-detects with onset/debounce, and writes trigger
-- notes into the target pattern column at the corresponding line + delay.
-- This is the offline path Joshua Montgomery originally asked about: take
-- an audio kick (or any rhythmic sample) and turn it into a trigger pattern.
--
-- opts:
--   sample              — renoise.Sample (default: song.selected_sample)
--   target_track_index  — 1-based (default: selected)
--   target_column_index — 1-based (default: 2)
--   trigger_instrument_index — 1-based (default: existing trigger instr)
--   threshold_db        — peaks below this are ignored (default -24)
--   onset_ratio         — peak must be onset_ratio× the previous (default 1.6)
--   debounce_lines      — minimum gap between hits (default 1)
--   pattern_only        — limit to current pattern length? (default true)
--   velocity_curve      — "linear" | "sqrt" | "squared" (default "sqrt")
--   start_line          — pattern line to begin writing at (default 1)

local function db_to_linear(db) return 10 ^ (db / 20) end

function PakettiSidechainCaptureFromSample(opts)
  opts = opts or {}
  local song = renoise.song()
  if not song then return end

  local sample = opts.sample or song.selected_sample
  if not sample or not sample.sample_buffer or not sample.sample_buffer.has_sample_data then
    renoise.app():show_status("Pick a sample with audio data first")
    return
  end

  local buf = sample.sample_buffer
  local channels = buf.number_of_channels
  local frames = buf.number_of_frames
  local sample_rate = buf.sample_rate

  local bpm = song.transport.bpm
  local lpb = song.transport.lpb
  local samples_per_line = sample_rate * 60 / (bpm * lpb)

  local target_track_idx  = opts.target_track_index  or song.selected_track_index
  local target_col_idx    = opts.target_column_index or 2
  local trig_idx          = opts.trigger_instrument_index or find_trigger_instrument_index() or 1
  local threshold         = db_to_linear(opts.threshold_db or -24)
  local onset_ratio       = opts.onset_ratio or 1.6
  local debounce_lines    = math.max(0, opts.debounce_lines or 1)
  local velocity_curve    = opts.velocity_curve or "sqrt"
  local start_line        = math.max(1, opts.start_line or 1)

  local pattern = song.selected_pattern
  if not pattern then return end
  local pattern_lines = pattern.number_of_lines

  local target_track = song.tracks[target_track_idx]
  if not target_track then
    renoise.app():show_status("Target track invalid")
    return
  end
  if target_col_idx > target_track.visible_note_columns then
    target_track.visible_note_columns = math.min(12, math.max(target_track.visible_note_columns, target_col_idx))
  end
  pcall(function() target_track:set_column_name(target_col_idx, "trigger") end)

  song:describe_undo("Paketti: Capture Trigger Notes from Sample")

  local pattern_track = pattern:track(target_track_idx)
  if not pattern_track then return end

  -- Walk buffer in line-sized windows
  local total_lines = math.floor(frames / samples_per_line)
  if opts.pattern_only ~= false then
    total_lines = math.min(total_lines, pattern_lines - start_line + 1)
  end

  local prev_peak = 0
  local debounce_remaining = 0
  local hits_written = 0

  for line_offset = 0, total_lines - 1 do
    local target_line_idx = start_line + line_offset
    if target_line_idx > pattern_lines then break end

    local f0 = math.floor(line_offset * samples_per_line) + 1
    local f1 = math.min(frames, math.floor((line_offset + 1) * samples_per_line))

    local peak = 0
    local peak_offset_in_window = 0
    for f = f0, f1 do
      local v = 0
      for ch = 1, channels do
        local s = math.abs(buf:sample_data(ch, f))
        if s > v then v = s end
      end
      if v > peak then
        peak = v
        peak_offset_in_window = f - f0
      end
    end

    local is_hit = (peak > threshold) and (peak > prev_peak * onset_ratio)
    if debounce_remaining > 0 then
      is_hit = false
      debounce_remaining = debounce_remaining - 1
    end

    if is_hit then
      local norm = peak  -- 0..1
      local vel
      if velocity_curve == "sqrt" then
        vel = math.sqrt(norm)
      elseif velocity_curve == "squared" then
        vel = norm * norm
      else
        vel = norm
      end
      local velocity_byte = math.max(1, math.min(127, math.floor(vel * 127 + 0.5)))

      local window_size = math.max(1, f1 - f0)
      local delay_byte = math.max(0, math.min(255, math.floor((peak_offset_in_window / window_size) * 256)))

      local line = pattern_track:line(target_line_idx)
      local col = line.note_columns[target_col_idx]
      if col then
        col.note_value = 48 -- C-4
        col.instrument_value = trig_idx - 1
        col.volume_value = velocity_byte
        col.delay_value = delay_byte
        hits_written = hits_written + 1
      end
      debounce_remaining = debounce_lines
    end

    prev_peak = peak
  end

  renoise.app():show_status(string.format(
    "Captured %d trigger note(s) from '%s' (%d lines analyzed, %.1f samples/line @ %.2f BPM × %d LPB)",
    hits_written, sample.name, total_lines, samples_per_line, bpm, lpb))
end

PakettiSidechainCaptureDialog = nil

function PakettiSidechainCaptureShowDialog()
  if PakettiSidechainCaptureDialog and PakettiSidechainCaptureDialog.visible then
    PakettiSidechainCaptureDialog:close()
    PakettiSidechainCaptureDialog = nil
    return
  end
  local song = renoise.song()
  if not song then return end

  local track_items = {}
  for i, t in ipairs(song.tracks) do
    table.insert(track_items, string.format("%02d: %s", i, t.name ~= "" and t.name or "<unnamed>"))
  end

  local instr_items = {}
  for i, instr in ipairs(song.instruments) do
    table.insert(instr_items, string.format("%02X: %s", i - 1, instr.name ~= "" and instr.name or "<unnamed>"))
  end
  local default_trig = find_trigger_instrument_index() or song.selected_instrument_index

  local vb = renoise.ViewBuilder()
  local content = vb:column{
    margin = 10, spacing = 6,

    vb:text{text = "Capture trigger notes from currently selected sample", style = "strong"},
    vb:text{text = "Walks the sample buffer in line-sized windows (BPM+LPB based) and writes trigger notes at every transient.", style = "disabled"},

    vb:row{
      vb:text{text = "Target track:", width = 130},
      vb:popup{id = "tgt_track", items = track_items, value = song.selected_track_index, width = 280}
    },
    vb:row{
      vb:text{text = "Target column:", width = 130},
      vb:valuebox{id = "tgt_col", min = 1, max = 12, value = 2, width = 60}
    },
    vb:row{
      vb:text{text = "Trigger instrument:", width = 130},
      vb:popup{id = "trig", items = #instr_items > 0 and instr_items or {"<none>"}, value = default_trig, width = 280}
    },
    vb:row{
      vb:text{text = "Threshold (dB):", width = 130},
      vb:valuebox{id = "thresh", min = -60, max = 0, value = -24, width = 60}
    },
    vb:row{
      vb:text{text = "Onset ratio:", width = 130},
      vb:valuebox{id = "onset", min = 1, max = 8, value = 2, width = 60},
      vb:text{text = "(peak must be N× the previous line's peak)", style = "disabled"}
    },
    vb:row{
      vb:text{text = "Debounce (lines):", width = 130},
      vb:valuebox{id = "deb", min = 0, max = 16, value = 1, width = 60}
    },
    vb:row{
      vb:text{text = "Velocity curve:", width = 130},
      vb:popup{id = "curve", items = {"Linear", "Sqrt (perceptual)", "Squared"}, value = 2, width = 200}
    },
    vb:row{
      vb:text{text = "Start at line:", width = 130},
      vb:valuebox{id = "start_line", min = 1, max = 512, value = 1, width = 60}
    },

    vb:row{
      spacing = 6,
      vb:button{
        text = "Capture",
        notifier = function()
          local curve_map = {"linear", "sqrt", "squared"}
          PakettiSidechainCaptureFromSample{
            target_track_index = vb.views.tgt_track.value,
            target_column_index = vb.views.tgt_col.value,
            trigger_instrument_index = vb.views.trig.value,
            threshold_db = vb.views.thresh.value,
            onset_ratio = vb.views.onset.value,
            debounce_lines = vb.views.deb.value,
            velocity_curve = curve_map[vb.views.curve.value] or "sqrt",
            start_line = vb.views.start_line.value
          }
        end
      },
      vb:button{
        text = "Close",
        notifier = function()
          if PakettiSidechainCaptureDialog then PakettiSidechainCaptureDialog:close() end
          PakettiSidechainCaptureDialog = nil
        end
      }
    }
  }
  PakettiSidechainCaptureDialog = renoise.app():show_custom_dialog(
    "Paketti: Capture Trigger Notes from Sample", content)
end

------------------------------------------------------------------------
-- Convenience helpers for common trigger flavors
------------------------------------------------------------------------

local function create_named(name)
  return function() PakettiCreateTriggerInstrument(name) end
end

local function create_prompt()
  local vb = renoise.ViewBuilder()
  local default_name = "trigger"
  local content = vb:column{
    margin = 10,
    spacing = 6,
    vb:text{text = "Trigger instrument name:", style = "strong"},
    vb:textfield{
      id = "trigger_name",
      width = 240,
      value = default_name
    },
    vb:row{
      spacing = 6,
      vb:button{
        text = "Create",
        width = 80,
        notifier = function()
          local name = vb.views.trigger_name.value
          if not name or name == "" then
            renoise.app():show_status("Trigger name cannot be empty")
            return
          end
          PakettiCreateTriggerInstrument(name)
          if PakettiCreateTriggerInstrumentDialog and PakettiCreateTriggerInstrumentDialog.visible then
            PakettiCreateTriggerInstrumentDialog:close()
            PakettiCreateTriggerInstrumentDialog = nil
          end
        end
      },
      vb:button{
        text = "Cancel",
        width = 80,
        notifier = function()
          if PakettiCreateTriggerInstrumentDialog and PakettiCreateTriggerInstrumentDialog.visible then
            PakettiCreateTriggerInstrumentDialog:close()
            PakettiCreateTriggerInstrumentDialog = nil
          end
        end
      }
    }
  }

  if PakettiCreateTriggerInstrumentDialog and PakettiCreateTriggerInstrumentDialog.visible then
    PakettiCreateTriggerInstrumentDialog:close()
    PakettiCreateTriggerInstrumentDialog = nil
    return
  end

  PakettiCreateTriggerInstrumentDialog = renoise.app():show_custom_dialog(
    "Paketti: Create Trigger Instrument",
    content
  )
end

------------------------------------------------------------------------
-- Menu entries
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Trigger Instrument:trigger (default)",
  invoke = create_named("trigger")
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Trigger Instrument:Kick Trigger",
  invoke = create_named("Kick Trigger")
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Trigger Instrument:Snare Trigger",
  invoke = create_named("Snare Trigger")
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Trigger Instrument:Hat Trigger",
  invoke = create_named("Hat Trigger")
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Trigger Instrument:Custom name...",
  invoke = create_prompt
}

PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:Create Sidechain Trigger Instrument",
  invoke = create_named("trigger")
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:Create Sidechain Trigger Instrument (custom name)...",
  invoke = create_prompt
}

------------------------------------------------------------------------
-- Keybindings (3 colon parts only, names flattened)
------------------------------------------------------------------------

renoise.tool():add_keybinding{
  name = "Global:Paketti:Create Sidechain Trigger Instrument",
  invoke = create_named("trigger")
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Create Sidechain Trigger Instrument Kick",
  invoke = create_named("Kick Trigger")
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Create Sidechain Trigger Instrument Snare",
  invoke = create_named("Snare Trigger")
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Create Sidechain Trigger Instrument Hat",
  invoke = create_named("Hat Trigger")
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Create Sidechain Trigger Instrument Custom",
  invoke = create_prompt
}

------------------------------------------------------------------------
-- MIDI mappings
------------------------------------------------------------------------

renoise.tool():add_midi_mapping{
  name = "Paketti:Create Sidechain Trigger Instrument",
  invoke = function(message)
    if message:is_trigger() then create_named("trigger")() end
  end
}

------------------------------------------------------------------------
-- Sidechain Doofer Auto-Loader registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Sidechain Doofer Auto-Loader...",
  invoke = PakettiSidechainDooferShowDialog
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Insert Sidechain Doofer (defaults)",
  invoke = function() PakettiInsertSidechainDoofer{} end
}

PakettiAddMenuEntry{
  name = "Mixer:Paketti:Sidechain Doofer Auto-Loader...",
  invoke = PakettiSidechainDooferShowDialog
}
PakettiAddMenuEntry{
  name = "Mixer:Paketti:Insert Sidechain Doofer (defaults)",
  invoke = function() PakettiInsertSidechainDoofer{} end
}

PakettiAddMenuEntry{
  name = "DSP Chain:Paketti:Sidechain Doofer Auto-Loader...",
  invoke = PakettiSidechainDooferShowDialog
}
PakettiAddMenuEntry{
  name = "DSP Chain:Paketti:Insert Sidechain Doofer (defaults)",
  invoke = function() PakettiInsertSidechainDoofer{} end
}

renoise.tool():add_keybinding{
  name = "Global:Paketti:Sidechain Doofer Auto-Loader Dialog",
  invoke = PakettiSidechainDooferShowDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Insert Sidechain Doofer Defaults",
  invoke = function() PakettiInsertSidechainDoofer{} end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Sidechain Doofer Auto-Loader Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiSidechainDooferShowDialog() end
  end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Insert Sidechain Doofer",
  invoke = function(message)
    if message:is_trigger() then PakettiInsertSidechainDoofer{} end
  end
}

------------------------------------------------------------------------
-- Trigger Column Mirror registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Trigger Column Mirror...",
  invoke = PakettiSidechainMirrorShowDialog
}
PakettiAddMenuEntry{
  name = "Pattern Editor:Paketti:Trigger Column Mirror...",
  invoke = PakettiSidechainMirrorShowDialog
}

renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Trigger Column Mirror Dialog",
  invoke = PakettiSidechainMirrorShowDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger Column Mirror Dialog",
  invoke = PakettiSidechainMirrorShowDialog
}
renoise.tool():add_keybinding{
  name = "Pattern Editor:Paketti:Tag Selected Note Column as Trigger",
  invoke = function() PakettiSidechainTagSelectedColumn("trigger") end
}

renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger Column Mirror Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiSidechainMirrorShowDialog() end
  end
}

------------------------------------------------------------------------
-- Trigger Phrase Library registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Generate Trigger Phrase Library",
  invoke = function() PakettiSidechainGenerateTriggerPhrases() end
}
PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:Generate Trigger Phrase Library",
  invoke = function() PakettiSidechainGenerateTriggerPhrases() end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Generate Trigger Phrase Library",
  invoke = function() PakettiSidechainGenerateTriggerPhrases() end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Generate Trigger Phrase Library",
  invoke = function(message)
    if message:is_trigger() then PakettiSidechainGenerateTriggerPhrases() end
  end
}

------------------------------------------------------------------------
-- Sidechain Recipe registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Save Sidechain Recipe...",
  invoke = PakettiSidechainSaveRecipePrompt
}
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Load Sidechain Recipe...",
  invoke = PakettiSidechainLoadRecipePrompt
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Save Sidechain Recipe Dialog",
  invoke = PakettiSidechainSaveRecipePrompt
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Load Sidechain Recipe Dialog",
  invoke = PakettiSidechainLoadRecipePrompt
}

------------------------------------------------------------------------
-- Trigger-Driven Modulator registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Trigger-Driven Modulator...",
  invoke = PakettiTriggerModulatorShowDialog
}
PakettiAddMenuEntry{
  name = "Mixer:Paketti:Trigger-Driven Modulator...",
  invoke = PakettiTriggerModulatorShowDialog
}
PakettiAddMenuEntry{
  name = "DSP Chain:Paketti:Trigger-Driven Modulator...",
  invoke = PakettiTriggerModulatorShowDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Trigger-Driven Modulator Dialog",
  invoke = PakettiTriggerModulatorShowDialog
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Trigger-Driven Modulator Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiTriggerModulatorShowDialog() end
  end
}

------------------------------------------------------------------------
-- Sidechain Hydra Fanout registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Insert Sidechain Hydra Fanout",
  invoke = function() PakettiInsertSidechainHydraFanout{} end
}
PakettiAddMenuEntry{
  name = "Mixer:Paketti:Insert Sidechain Hydra Fanout",
  invoke = function() PakettiInsertSidechainHydraFanout{} end
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Insert Sidechain Hydra Fanout",
  invoke = function() PakettiInsertSidechainHydraFanout{} end
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Insert Sidechain Hydra Fanout",
  invoke = function(message)
    if message:is_trigger() then PakettiInsertSidechainHydraFanout{} end
  end
}

------------------------------------------------------------------------
-- Sample → Trigger Notes registrations
------------------------------------------------------------------------

PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:DSP:Capture Trigger Notes from Sample...",
  invoke = PakettiSidechainCaptureShowDialog
}
PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:Capture Trigger Notes from Sample...",
  invoke = PakettiSidechainCaptureShowDialog
}
renoise.tool():add_keybinding{
  name = "Sample Editor:Paketti:Capture Trigger Notes from Sample Dialog",
  invoke = PakettiSidechainCaptureShowDialog
}
renoise.tool():add_keybinding{
  name = "Global:Paketti:Capture Trigger Notes from Sample Dialog",
  invoke = PakettiSidechainCaptureShowDialog
}
renoise.tool():add_midi_mapping{
  name = "Paketti:Capture Trigger Notes from Sample Dialog",
  invoke = function(message)
    if message:is_trigger() then PakettiSidechainCaptureShowDialog() end
  end
}
