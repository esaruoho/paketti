-- PakettiMultitimbralMidiInput.lua
-- One-shot multitimbral MIDI-input setup.
--
-- Assigns every instrument's MIDI input to one chosen device, giving each
-- instrument a sequential MIDI channel (instrument 1 -> ch 1, instrument 2 ->
-- ch 2, ...) and, optionally, routing it to the matching track and prefixing its
-- name with [CHxx]. This is the fast way to wire up a multitimbral rig where one
-- external keyboard/controller drives many instruments, each on its own channel.
--
-- MIDI has 16 channels, so this caps at the first 16 instruments.
--
-- (Paketti's MIDI Populator does the same wiring while CREATING instruments; this
-- retro-fits the assignment onto instruments that already exist.)

local MAX_MIDI_CHANNELS = 16

local dialog = nil
local prefix_names   = true
local assign_tracks  = true

-- "[CH03] Bass" <- ("Bass", 3); replaces any existing [CHxx] prefix.
local function channel_prefix(name, ch)
  local base = name:match("^%[CH%d%d%]%s*(.+)") or name
  return string.format("[CH%02d] %s", ch, base)
end

function PakettiMultitimbralAssign(device_name)
  if not device_name or device_name == "" then
    renoise.app():show_status("No MIDI input device chosen.")
    return
  end
  local song = renoise.song()
  local count = math.min(#song.instruments, MAX_MIDI_CHANNELS)
  if count == 0 then
    renoise.app():show_status("No instruments to assign.")
    return
  end
  local track_count = song.sequencer_track_count

  for i = 1, count do
    local instr = song.instruments[i]
    instr.midi_input_properties.device_name = device_name
    instr.midi_input_properties.channel = i
    if assign_tracks and i <= track_count then
      instr.midi_input_properties.assigned_track = i
    end
    if prefix_names then
      instr.name = channel_prefix(instr.name, i)
    end
  end

  local msg = string.format("Assigned %d instrument(s) to '%s', channels 01-%02d",
    count, device_name, count)
  if #song.instruments > MAX_MIDI_CHANNELS then
    msg = msg .. string.format(" (instruments %d+ skipped — only 16 MIDI channels)",
      MAX_MIDI_CHANNELS + 1)
  end
  renoise.app():show_status(msg)
end

function PakettiMultitimbralMidiInputDialog()
  if dialog and dialog.visible then
    dialog:close()
    dialog = nil
    return
  end

  local devices = renoise.Midi.available_input_devices()
  if #devices == 0 then
    renoise.app():show_warning("No MIDI input devices are available.")
    return
  end

  local vb = renoise.ViewBuilder()
  local device_field  = "mtmb_device_"  .. tostring(math.random(2, 30000))
  local prefix_field  = "mtmb_prefix_"  .. tostring(math.random(2, 30000))
  local tracks_field  = "mtmb_tracks_"  .. tostring(math.random(2, 30000))

  local content = vb:column{
    margin = 10, spacing = 8,
    vb:text{text = "Multitimbral MIDI Input Setup", font = "bold"},
    vb:text{text = "Assigns each instrument (up to 16) to one MIDI device,\none MIDI channel per instrument."},
    vb:row{
      vb:text{text = "MIDI Input Device:", width = 130},
      vb:popup{id = device_field, width = 260, items = devices, value = 1},
    },
    vb:row{
      vb:checkbox{id = tracks_field, value = assign_tracks,
        notifier = function(v) assign_tracks = v end},
      vb:text{text = "Assign each instrument to its matching track"},
    },
    vb:row{
      vb:checkbox{id = prefix_field, value = prefix_names,
        notifier = function(v) prefix_names = v end},
      vb:text{text = "Prefix instrument names with [CHxx]"},
    },
    vb:row{
      vb:button{text = "Assign", width = 100, notifier = function()
        local dev = devices[vb.views[device_field].value]
        PakettiMultitimbralAssign(dev)
      end},
      vb:button{text = "Close", width = 100, notifier = function()
        if dialog and dialog.visible then dialog:close() dialog = nil end
      end},
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return dialog end,
    function(value) dialog = value end
  )
  dialog = renoise.app():show_custom_dialog(
    "Paketti Multitimbral MIDI Input Setup", content, keyhandler)
end

renoise.tool():add_keybinding{name="Global:Paketti:Multitimbral MIDI Input Setup...", invoke=PakettiMultitimbralMidiInputDialog}
PakettiAddMenuEntry{name="Main Menu:Tools:Paketti:Instruments:Multitimbral MIDI Input Setup...", invoke=PakettiMultitimbralMidiInputDialog}
PakettiAddMenuEntry{name="Instrument Box:Paketti:Multitimbral MIDI Input Setup...", invoke=PakettiMultitimbralMidiInputDialog}
renoise.tool():add_midi_mapping{name="Paketti:Multitimbral MIDI Input Setup", invoke=function(m) if m:is_trigger() then PakettiMultitimbralMidiInputDialog() end end}
