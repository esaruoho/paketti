-- FEATURE-CARD >> features/loop-crossfade.feature
-- Pre-loop-to-tail workflow inspired by Phaos SimpleXfade and afta8 xfade pow.
-- Independently implemented; no third-party source bundled.
local dialog
local settings = {curve="equal_power", length_mode="auto", length=100, region="selection", units="frames"}

function PakettiLoopCrossfadeSelection(buffer)
  local r = buffer.selection_range
  if r and r[2] > r[1] and not (r[1] == 1 and r[2] == buffer.number_of_frames) then
    return r[1], r[2]
  end
end

function PakettiLoopCrossfadeSample(sample, first, last, options, make_loop)
  options = options or settings
  local buffer = sample.sample_buffer
  if not buffer.has_sample_data then return nil, "empty" end
  if buffer.read_only then return nil, "slice" end
  if not make_loop and sample.loop_mode ~= renoise.Sample.LOOP_MODE_FORWARD then
    return nil, "needs forward loop"
  end
  local n = buffer.number_of_frames
  if first < 1 or last > n or last <= first then return nil, "invalid loop range" end
  local maximum = math.min(last-first+1, first-1)
  local fade = maximum
  if options.length_mode ~= "auto" then
    local amount = tonumber(options.length)
    if not amount or amount ~= amount or amount == math.huge or amount <= 0 then
      return nil, "invalid fade length"
    end
    if options.length_mode == "ms" then amount = amount * buffer.sample_rate / 1000 end
    fade = math.min(maximum, math.floor(amount + 0.5))
  end
  if fade < 2 then return nil, "needs two pre-loop/fade frames" end
  if options.curve ~= "linear" and options.curve ~= "equal_power" then return nil, "invalid curve" end
  -- Renoise sample storage is bounded to [-1,1]. Reject unsafe blends before
  -- writing rather than silently clipping or normalizing unrelated audio.
  if options.curve == "equal_power" then
    for ch=1,buffer.number_of_channels do
      for i=0,fade-1 do
        local t = (i+1)/fade
        local a,z = math.sin(t*math.pi/2),math.cos(t*math.pi/2)
        if i == fade-1 then a,z=1,0 end
        local value = buffer:sample_data(ch,last-fade+1+i)*z
          + buffer:sample_data(ch,first-fade+i)*a
        if math.abs(value) > 1 then return nil, "peak exceeds headroom; lower gain or use Linear" end
      end
    end
  end
  local prepared = false
  local ok, err = pcall(function()
    buffer:prepare_sample_data_changes()
    prepared = true
    for ch=1,buffer.number_of_channels do
      for i=0,fade-1 do
        local t = (i+1)/fade
        local incoming, outgoing = t, 1-t
        if options.curve == "equal_power" then
          incoming, outgoing = math.sin(t*math.pi/2), math.cos(t*math.pi/2)
        end
        -- End on the original pre-loop frame exactly (avoid cos(pi/2) residue).
        if i == fade-1 then incoming, outgoing = 1, 0 end
        local source, dest = first-fade+i, last-fade+1+i
        buffer:set_sample_data(ch, dest,
          buffer:sample_data(ch,dest)*outgoing + buffer:sample_data(ch,source)*incoming)
      end
    end
  end)
  if prepared then
    local finalized, final_err = pcall(function() buffer:finalize_sample_data_changes() end)
    if not finalized then return nil, "finalize failed: " .. tostring(final_err) end
  end
  if not ok then return nil, "write failed (Undo may be needed): " .. tostring(err) end
  if make_loop then
    local marked, marker_err = pcall(function()
      sample.loop_start = 1
      sample.loop_end = last
      sample.loop_start = first
      sample.loop_mode = renoise.Sample.LOOP_MODE_FORWARD
    end)
    if not marked then return nil, "loop markers failed (Undo may be needed): " .. tostring(marker_err) end
  end
  return fade
end

function PakettiLoopCrossfadeApply(scope, options)
  options = options or settings
  local song = renoise.song()
  local selected = song.selected_sample
  local inst = song.selected_instrument
  if not inst or (scope ~= "instrument" and not selected) then
    renoise.app():show_status("Crossfade: no sample/instrument selected.") return
  end
  local first, last, reference_rate
  if options.region == "selection" and selected and selected.sample_buffer.has_sample_data then
    first, last = PakettiLoopCrossfadeSelection(selected.sample_buffer)
    reference_rate = selected.sample_buffer.sample_rate
  end
  -- No meaningful selection: each sample uses its own forward loop.
  local targets = scope == "instrument" and inst.samples or {selected}
  local done, skipped, fade_ms = 0, {}, nil
  song:describe_undo("Paketti Loop Crossfade")
  for _,sample in ipairs(targets) do
    local a,z = first,last
    if a and options.units == "time" then
      local ratio = sample.sample_buffer.sample_rate/reference_rate
      a = math.floor((first-1)*ratio+0.5)+1
      z = math.floor(last*ratio+0.5)
    end
    if not a then a,z = sample.loop_start,sample.loop_end end
    local fade,reason = PakettiLoopCrossfadeSample(sample,a,z,options,first ~= nil)
    if fade then
      done = done+1
      fade_ms = fade*1000/sample.sample_buffer.sample_rate
    else skipped[reason] = (skipped[reason] or 0)+1 end
  end
  local reasons = {}
  for reason,count in pairs(skipped) do reasons[#reasons+1] = count .. " " .. reason end
  table.sort(reasons)
  local detail = #reasons > 0 and ("; skipped: " .. table.concat(reasons,", ")) or ""
  if scope ~= "instrument" and fade_ms then detail = string.format("; fade %.3f ms",fade_ms) end
  renoise.app():show_status(string.format("Crossfade: %d/%d samples%s",done,#targets,detail))
end

function PakettiLoopCrossfadeDialog()
  if dialog and dialog.visible then dialog:close() return end
  local vb = renoise.ViewBuilder()
  local length = vb:valuebox {min=0.001,max=100000000,value=settings.length,
    notifier=function(v) settings.length=v end}
  length.active = settings.length_mode ~= "auto"
  dialog = renoise.app():show_custom_dialog("Paketti Loop Crossfade",vb:column {
    margin=10,spacing=8,
    vb:text {text="Blend audio before the loop into its tail. Requires pre-loop audio."},
    vb:row {vb:text {text="Region",width=90},vb:popup {items={"Selection, else existing loop","Existing loop"},
      value=settings.region=="selection" and 1 or 2,
      notifier=function(v) settings.region=v==1 and "selection" or "loop" end}},
    vb:row {vb:text {text="Curve",width=90},vb:popup {items={"Linear","Equal Power"},
      value=settings.curve=="linear" and 1 or 2,
      notifier=function(v) settings.curve=v==1 and "linear" or "equal_power" end}},
    vb:row {vb:text {text="Fade length",width=90},vb:popup {items={"Auto","Frames","Milliseconds"},
      value=settings.length_mode=="auto" and 1 or (settings.length_mode=="frames" and 2 or 3),
      notifier=function(v) settings.length_mode=({"auto","frames","ms"})[v]; length.active=v~=1 end},length},
    vb:row {vb:text {text="Batch selection",width=90},vb:popup {items={"Same frames","Same time"},
      value=settings.units=="frames" and 1 or 2,
      notifier=function(v) settings.units=v==1 and "frames" or "time" end}},
    vb:text {text="Auto can fade the entire loop. Equal Power can raise correlated peaks."},
    vb:text {text="Selection creates a forward loop; existing loops must already be forward."},
    vb:row {vb:button {text="Crossfade Sample",notifier=function() PakettiLoopCrossfadeApply("sample") end},
      vb:button {text="Crossfade Instrument",notifier=function() PakettiLoopCrossfadeApply("instrument") end},
      vb:button {text="Close",notifier=function() dialog:close() end}}
  },my_keyhandler_func)
end

renoise.tool():add_menu_entry {name="Sample Editor:Paketti:Process:Loop Crossfade...",invoke=PakettiLoopCrossfadeDialog}
renoise.tool():add_menu_entry {name="Main Menu:Tools:Paketti:Samples:Loop Crossfade...",invoke=PakettiLoopCrossfadeDialog}
renoise.tool():add_keybinding {name="Sample Editor:Paketti:Loop Crossfade Dialog...",
  invoke=function(repeated) if not repeated then PakettiLoopCrossfadeDialog() end end}
for _,scope in ipairs({"sample","instrument"}) do
  local target = scope
  local label = scope=="sample" and "Sample" or "Instrument"
  renoise.tool():add_keybinding {name="Sample Editor:Paketti:Loop Crossfade " .. label,
    invoke=function(repeated) if not repeated then PakettiLoopCrossfadeApply(target) end end}
  renoise.tool():add_midi_mapping {name="Paketti:Loop Crossfade " .. label,
    invoke=function(msg) if msg:is_trigger() then PakettiLoopCrossfadeApply(target) end end}
end
