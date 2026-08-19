--[[============================================================================
PakettiSliceFades.lua

Destructive fades on slice boundaries — the "autotrim slices so they fade out at
the end by xx ms" idea.

Autofade (the sample property) already does a click-free fade at playback time,
and for most people that is the right answer. This is for when you want it baked
into the audio: exported slices, hardware that has no autofade, or simply
wanting to see the fade in the waveform.

--------------------------------------------------------------------------------
HOW IT WORKS
--------------------------------------------------------------------------------
Slice samples in Renoise are aliases: their buffers are read-only (probed live —
writing to `instrument.samples[2].sample_buffer` fails, writing to
`instrument.samples[1].sample_buffer` succeeds even while slice markers exist).

So the fades are written into the PARENT sample's buffer at the slice region
boundaries. Region k runs from slice marker k up to the frame before marker
k+1, and the last region runs to the end of the sample. If the first marker is
not on frame 1 then the audio before it is a region too.

A fade is never allowed to eat more than half a region, so short slices get
proportionally shorter fades instead of being silenced.

This is destructive and it is one undo step — Renoise's own sample undo covers
it, because the whole pass sits inside a single
prepare_sample_data_changes()/finalize_sample_data_changes() pair.
============================================================================]]--

-- Applies a linear fade-out of `fade_out_ms` to the end of every slice region,
-- and a fade-in of `fade_in_ms` to the start of every slice region. Either can
-- be 0. Returns ok, message.
function PakettiSliceFadeApply(fade_out_ms, fade_in_ms)
  local song = renoise.song()
  local instrument = song.selected_instrument
  if not instrument or #instrument.samples == 0 then
    return false, "no instrument with samples selected"
  end

  local sample = instrument.samples[1]
  local buffer = sample.sample_buffer
  if not buffer or not buffer.has_sample_data then
    return false, "the first sample has no audio data"
  end

  local markers = sample.slice_markers
  if #markers == 0 then
    return false, "this sample has no slices"
  end

  fade_out_ms = fade_out_ms or 0
  fade_in_ms = fade_in_ms or 0
  if fade_out_ms <= 0 and fade_in_ms <= 0 then
    return false, "both fade lengths are zero"
  end

  local rate = buffer.sample_rate
  local frames = buffer.number_of_frames
  local channels = buffer.number_of_channels
  local want_out = math.floor(rate * fade_out_ms / 1000 + 0.5)
  local want_in = math.floor(rate * fade_in_ms / 1000 + 0.5)

  -- region starts: the head of the sample counts too when the first marker is
  -- not sitting on frame 1
  local starts = {}
  if markers[1] > 1 then starts[#starts + 1] = 1 end
  for _, marker in ipairs(markers) do starts[#starts + 1] = marker end

  buffer:prepare_sample_data_changes()

  local faded, shortened = 0, 0
  for i = 1, #starts do
    local first = starts[i]
    local last = (starts[i + 1] and starts[i + 1] - 1) or frames
    local length = last - first + 1
    if length > 1 then
      local half = math.floor(length / 2)
      local out_frames = math.min(want_out, half)
      local in_frames = math.min(want_in, half)
      if out_frames < want_out or in_frames < want_in then shortened = shortened + 1 end

      for n = 0, in_frames - 1 do
        local gain = n / in_frames
        local position = first + n
        for channel = 1, channels do
          buffer:set_sample_data(channel, position, buffer:sample_data(channel, position) * gain)
        end
      end

      for n = 0, out_frames - 1 do
        local gain = n / out_frames
        local position = last - n
        for channel = 1, channels do
          buffer:set_sample_data(channel, position, buffer:sample_data(channel, position) * gain)
        end
      end

      faded = faded + 1
    end
  end

  buffer:finalize_sample_data_changes()

  local message = string.format("%d slice regions faded", faded)
  if fade_in_ms > 0 and fade_out_ms > 0 then
    message = message .. string.format(" (%gms in, %gms out)", fade_in_ms, fade_out_ms)
  elseif fade_out_ms > 0 then
    message = message .. string.format(" (%gms out)", fade_out_ms)
  else
    message = message .. string.format(" (%gms in)", fade_in_ms)
  end
  if shortened > 0 then
    message = message .. string.format(", %d were too short for the full fade", shortened)
  end
  return true, message
end

function PakettiSliceFadeOut(ms)
  local ok, message = PakettiSliceFadeApply(ms, 0)
  renoise.app():show_status("Slice Fades: " .. message)
  if ok then print("PakettiSliceFades: " .. message) end
end

function PakettiSliceFadeBothEnds(ms)
  local ok, message = PakettiSliceFadeApply(ms, ms)
  renoise.app():show_status("Slice Fades: " .. message)
  if ok then print("PakettiSliceFades: " .. message) end
end

--------------------------------------------------------------------------------
-- dialog
--------------------------------------------------------------------------------

local slice_fade_dialog = nil

function PakettiSliceFadeDialog()
  if slice_fade_dialog and slice_fade_dialog.visible then
    slice_fade_dialog:close()
    slice_fade_dialog = nil
    return
  end

  local vb = renoise.ViewBuilder()
  local out_id = "slice_fade_out_" .. tostring(math.random(2, 30000))
  local in_id = "slice_fade_in_" .. tostring(math.random(2, 30000))

  local content = vb:column{
    margin = renoise.ViewBuilder.DEFAULT_DIALOG_MARGIN,
    spacing = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING,
    vb:text{text = "Bakes fades into the sample at every slice boundary."},
    vb:row{
      vb:text{text = "Fade Out (ms)", width = 100},
      vb:valuebox{id = out_id, min = 0, max = 500, value = preferences.pakettiSliceFadeOutMs.value,
        notifier = function(value)
          preferences.pakettiSliceFadeOutMs.value = value
          preferences:save_as("preferences.xml")
        end},
    },
    vb:row{
      vb:text{text = "Fade In (ms)", width = 100},
      vb:valuebox{id = in_id, min = 0, max = 500, value = preferences.pakettiSliceFadeInMs.value,
        notifier = function(value)
          preferences.pakettiSliceFadeInMs.value = value
          preferences:save_as("preferences.xml")
        end},
    },
    vb:row{
      vb:button{text = "Apply to Slices", width = 120, notifier = function()
        local ok, message = PakettiSliceFadeApply(vb.views[out_id].value, vb.views[in_id].value)
        renoise.app():show_status("Slice Fades: " .. message)
      end},
      vb:button{text = "Close", width = 60, notifier = function()
        if slice_fade_dialog and slice_fade_dialog.visible then slice_fade_dialog:close() end
        slice_fade_dialog = nil
      end},
    },
  }

  local keyhandler = create_keyhandler_for_dialog(
    function() return slice_fade_dialog end,
    function(value) slice_fade_dialog = value end)
  slice_fade_dialog = renoise.app():show_custom_dialog("Paketti Slice Fades", content, keyhandler)
end

--------------------------------------------------------------------------------
-- registrations
--------------------------------------------------------------------------------

PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Slice Tools:Slice Fades Dialog...",
  invoke = function() PakettiSliceFadeDialog() end}
PakettiAddMenuEntry{name = "Sample Editor:Paketti:Slice Fades:Slice Fades Dialog...",
  invoke = function() PakettiSliceFadeDialog() end}
PakettiAddMenuEntry{name = "Instrument Box:Paketti:Slice Fades:Slice Fades Dialog...",
  invoke = function() PakettiSliceFadeDialog() end}

renoise.tool():add_keybinding{name = "Global:Paketti:Slice Fades Dialog...",
  invoke = function() PakettiSliceFadeDialog() end}
renoise.tool():add_midi_mapping{name = "Paketti:Slice Fades Dialog",
  invoke = function(message) if message:is_trigger() then PakettiSliceFadeDialog() end end}

for _, ms in ipairs({0.5, 1, 2, 5, 10, 20}) do
  local label = string.format("%gms", ms)
  PakettiAddMenuEntry{name = "Main Menu:Tools:Paketti:Slice Tools:Fade Out Slice Ends " .. label,
    invoke = function() PakettiSliceFadeOut(ms) end}
  PakettiAddMenuEntry{name = "Sample Editor:Paketti:Slice Fades:Fade Out Slice Ends " .. label,
    invoke = function() PakettiSliceFadeOut(ms) end}
  PakettiAddMenuEntry{name = "Sample Editor:Paketti:Slice Fades:Fade Both Slice Ends " .. label,
    invoke = function() PakettiSliceFadeBothEnds(ms) end}
  renoise.tool():add_keybinding{name = "Global:Paketti:Fade Out Slice Ends " .. label,
    invoke = function() PakettiSliceFadeOut(ms) end}
  renoise.tool():add_keybinding{name = "Global:Paketti:Fade Both Slice Ends " .. label,
    invoke = function() PakettiSliceFadeBothEnds(ms) end}
  renoise.tool():add_midi_mapping{name = "Paketti:Fade Out Slice Ends " .. label,
    invoke = function(message) if message:is_trigger() then PakettiSliceFadeOut(ms) end end}
end
