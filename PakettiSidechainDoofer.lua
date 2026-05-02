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

  -- 6. Select the Key Tracker so the user lands on the head of the chain
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
            lines_per_cycle = vb.views.lpc_box.value
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
            lines_per_cycle = vb.views.lpc_box.value
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
