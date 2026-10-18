-- REPORT-CARD >> features/track-mute-controller.feature
-- Shared by the setup and performance dialogs. Renoise is the source of truth.
PakettiTrackMute = {}
local M = PakettiTrackMute
local config = renoise.Document.create("PakettiTrackMuteSettings") {
  input = "", output = "", channel = 10, output_channel = 10,
  notes = "36,37,38,39,40,41,42,43", first_track = 1,
  input_kind = 1, behavior = 1, feedback = false,
  active_value = 127, muted_value = 0, message_kind = 1
}
local settings_path = renoise.tool().bundle_path .. "TrackMuteControllerSettings.xml"
pcall(function() config:load_from(settings_path) end)
M.config = config
local input, output, setup_dialog, modes_dialog, views
local previous_led, edges, held = {}, {}, {}
local note_map = {}
local error_text = "Stopped"
local testing_leds = false
local last_message = ""

local function save()
  config:save_as(settings_path)
end

function M.parse_notes(text)
  local result, seen = {}, {}
  for token in (text .. ","):gmatch("([^,]*),") do
    local value = tonumber(token)
    if not value or value % 1 ~= 0 or value < 0 or value > 127 or seen[value] then
      return nil, "Use unique MIDI numbers 0–127 separated by commas."
    end
    seen[value] = true
    result[#result + 1] = value
  end
  if #result < 1 or #result > 16 then return nil, "Configure between 1 and 16 pads." end
  return result
end

local function track_for_pad(pad)
  local song = renoise.song()
  local index = config.first_track.value + pad - 1
  local track = song and song.tracks[index]
  if track and track.type == renoise.Track.TRACK_TYPE_SEQUENCER then return track, index end
end

local function send(note, value)
  if output then
    output:send({(config.message_kind.value == 1 and 0x90 or 0xB0) + config.output_channel.value - 1, note, value})
  end
end

local function restore_held()
  for track, original in pairs(held) do
    pcall(function() track.mute_state = original end)
  end
  held = {}
end

function M.stop()
  if renoise.tool():has_timer(M.refresh) then renoise.tool():remove_timer(M.refresh) end
  if renoise.tool():has_timer(M.finish_led_test) then renoise.tool():remove_timer(M.finish_led_test) end
  testing_leds = false
  restore_held()
  if output then
    pcall(function() for _, note in ipairs(note_map) do send(note, 0) end end)
    pcall(function() output:close() end)
  end
  if input then pcall(function() input:close() end) end
  input, output = nil, nil
  previous_led, edges = {}, {}
  error_text = "Stopped"
  if views and views.status then views.status.text = error_text end
end

function M.toggle(pad)
  local track = track_for_pad(pad)
  if track then
    track.mute_state = track.mute_state == renoise.Track.MUTE_STATE_ACTIVE
      and renoise.Track.MUTE_STATE_MUTED or renoise.Track.MUTE_STATE_ACTIVE
  end
  M.refresh()
end

function M.on_midi(message)
  if not input or type(message) ~= "table" or #message < 3 then return end
  local status, number, value = message[1], message[2], message[3]
  if status % 16 + 1 ~= config.channel.value then return end
  local kind = math.floor(status / 16)
  if kind ~= 8 and kind ~= 9 and kind ~= 11 then return end
  if config.message_kind.value == 1 and kind == 11 then return end
  if config.message_kind.value == 2 and kind ~= 11 then return end
  local down = kind ~= 8 and value > 0
  local pad
  for i, note in ipairs(note_map) do if note == number then pad = i break end end
  if not pad then return end
  last_message = string.format(" | pad %d: %s %d", pad, kind == 11 and "CC" or (kind == 8 and "Off" or "On"), value)
  local old = edges[pad] or false
  if old == down then return end -- aftertouch/repeated CC values cannot retrigger
  edges[pad] = down
  local track = track_for_pad(pad)
  if not track then return end
  if config.behavior.value == 1 then
    -- Momentary: positive edge only. Hardware toggle: both alternating edges.
    if down or config.input_kind.value == 2 then M.toggle(pad) end
  elseif down then
    if held[track] == nil then held[track] = track.mute_state end
    track.mute_state = config.behavior.value == 2
      and renoise.Track.MUTE_STATE_MUTED or renoise.Track.MUTE_STATE_ACTIVE
  elseif held[track] ~= nil then
    track.mute_state = held[track]
    held[track] = nil
  end
  M.refresh()
end

function M.refresh()
  -- A closed performance window does not stop the bridge.
  local ok, err = pcall(function()
    for pad, note in ipairs(note_map) do
      local track, index = track_for_pad(pad)
      local active = track and track.mute_state == renoise.Track.MUTE_STATE_ACTIVE
      local value = track and (active and config.active_value.value or config.muted_value.value) or 0
      if output and not testing_leds and previous_led[pad] ~= value then send(note, value) previous_led[pad] = value end
      if views and views[pad] then
        local button = views[pad]
        button.text = track and string.format("%02d  %s  %s", index, track.name, active and "ON" or "MUTED") or "—"
        button.active = track ~= nil
        button.color = track and (active and {70,160,90} or {190,65,65}) or {50,50,50}
      end
    end
    if views and views.status then views.status.text = error_text .. last_message end
  end)
  if not ok then
    error_text = "Bridge error: " .. tostring(err)
    print("Track Mute: " .. error_text)
    M.stop()
    error_text = "Stopped after MIDI/device error: " .. tostring(err)
    if views and views.status then views.status.text = error_text end
  end
end

function M.ui_refresh()
  if modes_dialog and modes_dialog.visible then M.refresh()
  elseif renoise.tool():has_timer(M.ui_refresh) then renoise.tool():remove_timer(M.ui_refresh) end
end

function M.release_family(fragment)
  if input and config.input.value:lower():find(fragment, 1, true) then M.stop() end
end

function M.start()
  M.stop()
  local parsed, err = M.parse_notes(config.notes.value)
  if not parsed then renoise.app():show_status(err) return false end
  note_map = parsed
  if config.input.value == "" then renoise.app():show_status("Choose a MIDI input first.") return false end
  -- These devices may already belong to an 8120 step bridge. Release that owner.
  local name = config.input.value:lower()
  if name:find("apc", 1, true) and PakettiEightOneTwentyAPCProbeClose then
    PakettiEightOneTwentyAPCSeqStop() PakettiEightOneTwentyAPCProbeClose()
  elseif name:find("lpd8", 1, true) and PakettiEightOneTwentyLPD8SeqStop then
    PakettiEightOneTwentyLPD8SeqStop()
  elseif name:find("mix", 1, true) and PakettiEightOneTwentyMidiMixClose then
    PakettiEightOneTwentyMidiMixClose()
  end
  local ok, dev = pcall(renoise.Midi.create_input_device, config.input.value, M.on_midi)
  if not ok or not dev then renoise.app():show_status("Cannot open input: " .. tostring(dev)) return false end
  input = dev
  if config.feedback.value then
    local out_ok, out_dev = pcall(renoise.Midi.create_output_device, config.output.value)
    if not out_ok or not out_dev then
      M.stop()
      renoise.app():show_status("Cannot open LED output: " .. tostring(out_dev))
      return false
    end
    output = out_dev
  end
  error_text = output and "Running — MIDI input + LED output" or "Running — MIDI input; LED output disabled"
  testing_leds = false
  save()
  renoise.tool():add_timer(M.refresh, 50)
  M.refresh()
  return input ~= nil
end

function M.finish_led_test()
  if renoise.tool():has_timer(M.finish_led_test) then renoise.tool():remove_timer(M.finish_led_test) end
  testing_leds = false
  previous_led = {}
  M.refresh()
end

function M.test_leds()
  if not output then renoise.app():show_status("Start with LED feedback enabled first.") return end
  local ok, err = pcall(function()
    for i, note in ipairs(note_map) do
      send(note, i % 2 == 1 and config.active_value.value or config.muted_value.value)
    end
  end)
  testing_leds = true
  if not renoise.tool():has_timer(M.finish_led_test) then renoise.tool():add_timer(M.finish_led_test, 1000) end
  previous_led = {} -- next refresh restores actual track state
  if not ok then M.stop() renoise.app():show_status(tostring(err)) end
end

local function close_key(dialog, key)
  if key.name == "esc" and key.modifiers == "" then dialog:close() return end
  return key
end

function PakettiTrackMuteControllerDialog()
  if setup_dialog and setup_dialog.visible then setup_dialog:show() return end
  local vb = renoise.ViewBuilder()
  local function device_popup(label, names, property)
    local items, selected = {"None"}, 1
    for _, name in ipairs(names) do
      items[#items + 1] = name
      if property.value == name then selected = #items end
    end
    return vb:row {vb:text {text=label, width=130}, vb:popup {items=items, value=selected, width=330,
      notifier=function(v) M.stop() property.value = v == 1 and "" or items[v] save() end}}
  end
  local function popup(label, items, property)
    return vb:row {vb:text {text=label, width=130}, vb:popup {items=items, value=property.value, width=330,
      notifier=function(v) M.stop() property.value=v save() end}}
  end
  local function number(label, property, min, max)
    return vb:row {vb:text {text=label, width=130}, vb:valuebox {min=min, max=max, value=property.value, width=80,
      notifier=function(v) M.stop() property.value=v save() end}}
  end
  local content = vb:column {margin=8, spacing=5,
    vb:text {text="Track Mute Controller", font="bold"},
    vb:text {text="Stop an existing 8120 step bridge before sharing the same controller."},
    device_popup("MIDI input", renoise.Midi.available_input_devices(), config.input),
    device_popup("LED MIDI output", renoise.Midi.available_output_devices(), config.output),
    number("Input channel", config.channel, 1, 16),
    number("Output channel", config.output_channel, 1, 16),
    popup("Pad messages", {"Notes", "Control Changes"}, config.message_kind),
    popup("Pad hardware mode", {"Momentary — press/release", "Toggle — alternating on/off taps"}, config.input_kind),
    vb:row {vb:text {text="Pad note / CC numbers", width=130}, vb:textfield {text=config.notes.value, width=330,
      notifier=function(v)
        local parsed, err = M.parse_notes(v)
        if parsed then
          M.stop() config.notes.value=v note_map=parsed save()
          if modes_dialog and modes_dialog.visible then modes_dialog:close() end
        else renoise.app():show_status(err) end
      end}},
    number("First track", config.first_track, 1, 512),
    vb:row {vb:checkbox {value=config.feedback.value, notifier=function(v) M.stop() config.feedback.value=v save() end},
      vb:text {text="Send LED feedback (requires host-controllable LEDs)"}},
    number("Track ON LED value", config.active_value, 0, 127),
    number("Muted LED value", config.muted_value, 0, 127),
    vb:text {text="LED values are model-specific. MPK support must be tested on your unit."},
    vb:text {text="APC Key 25 mk1: channel 1, green 1 / red 3. MIDImix: 127 / 0."},
    vb:text {text="Pad messages only are handled here; keep keyboard/knobs mapped in Renoise."},
    vb:row {
      vb:button {text="Start", notifier=M.start}, vb:button {text="Stop", notifier=M.stop},
      vb:button {text="Test LEDs", notifier=M.test_leds},
      vb:button {text="Track Mute Modes...", notifier=function() PakettiTrackMuteModesDialog() end}}
  }
  setup_dialog = renoise.app():show_custom_dialog("Paketti Track Mute Controller", content, close_key)
end

function PakettiTrackMuteModesDialog()
  if modes_dialog and modes_dialog.visible then modes_dialog:show() return end
  local parsed = M.parse_notes(config.notes.value)
  note_map = parsed or {36,37,38,39,40,41,42,43}
  local vb = renoise.ViewBuilder()
  views = {}
  local rows = vb:column {spacing=3}
  for pad = 1, #note_map do
    local p = pad
    views[p] = vb:button {text="—", width=440, notifier=function() M.toggle(p) end}
    rows:add_child(vb:row {vb:text {text="Pad " .. p, width=50}, views[p]})
  end
  views.status = vb:text {text=error_text, width=490}
  local function page(delta)
    restore_held()
    config.first_track.value = math.max(1, math.min(512, config.first_track.value + delta * #note_map))
    edges, previous_led = {}, {}
    save() M.refresh()
  end
  local content = vb:column {margin=8, spacing=5,
    vb:text {text="Track Mute Modes", font="bold"},
    vb:popup {items={"Toggle mute on each tap", "Hold to mute; release restores", "Hold to enable; release restores"},
      value=config.behavior.value, width=490, notifier=function(v) restore_held() edges={} config.behavior.value=v save() end},
    vb:text {text="Green = track ON; red = muted/off. Click a track to toggle."}, rows,
    vb:row {vb:button {text="Previous tracks", notifier=function() page(-1) end},
      vb:button {text="Next tracks", notifier=function() page(1) end},
      vb:button {text="Controller setup...", notifier=PakettiTrackMuteControllerDialog}},
    vb:row {vb:button {text="Start", notifier=M.start}, vb:button {text="Stop", notifier=M.stop},
      vb:button {text="Resync LEDs", notifier=function() previous_led={} M.refresh() end}},
    views.status,
    vb:text {text="Closing the dialog keeps the bridge running. Stop restores held mutes."}
  }
  modes_dialog = renoise.app():show_custom_dialog("Paketti Track Mute Modes", content, close_key)
  if not renoise.tool():has_timer(M.ui_refresh) then renoise.tool():add_timer(M.ui_refresh, 50) end
  M.refresh()
end

renoise.tool().app_release_document_observable:add_notifier(M.stop)
renoise.tool().app_new_document_observable:add_notifier(function() edges={} previous_led={} M.refresh() end)
renoise.tool():add_menu_entry {name="Main Menu:Tools:Paketti:Controllers:Track Mute Controller...", invoke=PakettiTrackMuteControllerDialog}
renoise.tool():add_menu_entry {name="Main Menu:Tools:Paketti:Controllers:Track Mute Modes...", invoke=PakettiTrackMuteModesDialog}
renoise.tool():add_keybinding {name="Global:Paketti:Track Mute Controller...", invoke=PakettiTrackMuteControllerDialog}
renoise.tool():add_keybinding {name="Global:Paketti:Track Mute Modes...", invoke=PakettiTrackMuteModesDialog}
renoise.tool():add_keybinding {name="Global:Paketti:Stop Track Mute Controller", invoke=M.stop}
