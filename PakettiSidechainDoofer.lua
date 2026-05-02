-- PakettiSidechainDoofer.lua
-- Sidechain Doofer infrastructure: trigger instrument generator, doofer loader,
-- trigger column mirror. Supports the Mr. Zensphere–style sidechain workflow
-- (Key Tracker → Custom LFO → Compressor) and any rhythm-locked parameter
-- modulation built on top of it.
--
-- This file currently ships:
--   • PakettiCreateTriggerInstrument(name)
-- Future additions (planned): auto-doofer loader, trigger column mirror,
-- velocity-sensitive variant.

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
