local function next_effect_chain(song, instrument, chain, dir)
  local next = chain + dir
  if next <= 0 then
    if instrument == 1 then
      return nil
    else
      local prev_instrument = song.instruments[instrument - 1]
      return next_effect_chain(song, instrument - 1, #prev_instrument.sample_device_chains - dir, dir)
    end
  elseif next > #song.instruments[instrument].sample_device_chains then
    if instrument == #song.instruments then
      return nil
    else
      return next_effect_chain(song, instrument + 1, 0, dir)
    end
  else
    return {instrument = instrument, chain = next}
  end
end

function parameter_palette(options)
  local initial = options.initial
  if type(initial) == "function" then
    initial = initial(renoise.song())
  end
  local model = {
    title = ifelse(prefs.ninja_mode.value, "", text_transform(options.title)),
    width = prefs.width.value,

    get_list = options.get_list,
    initial = initial,

    untouched = true,
    text_input = "",

    tips = {
      "left-right        : coarse nudge parameter",
      "ctrl + left-right : fine nudge parameter",
      "ctrl + enter      : write parameter to pattern",
      "alt + left-right  : select device",
      "alt + up-down     : select track/sample",
    },

    track_index = options.track_index,
    device_index = options.device_index,
    device = options.device,

    selected = initial,
    scroll = 0,
    list = options.get_list(options),
    constant_list = options.get_list(options),
  }

  model.scroll = clamp(model.selected - 2, 0, math.max(#model.list - prefs.max_results.value, 0))

  local item_view = options.item_view and options.item_view
    or function(item)
      if item.type == "header" then
        return {
          normal_text("<"),
          ifelse(options.device.is_active, strong_text("Active"), soft_text("Bypassed")),
          normal_text(">"),
        }
      elseif item.type == "preset" then
        local preset = options.device.active_preset and options.device.presets[options.device.active_preset] or ""
        return {
          soft_text("0"),
          normal_text("Preset"),
          raw_text(preset),
        }
      else
        return {
          soft_text(item.index),
          normal_text(item.name),
          raw_text(item.parameter.value_string),
        }
      end
    end

  return finder_list({
    title = model.title,
    model = model,
    callback = function(_, _, _) end,
    finish = options.finish and options.finish or function(_) end,
    init = options.init and options.init or function(m)
      m.untouched = true
      return m
    end,
    view = function(m)
      local vb = renoise.ViewBuilder()
      return vb:column({
        width = "100%",
        vb:row({
          raw_text(m.text_input),
        }),
        ifelse(prefs.ninja_mode.value, nil, list_view3(m.list, item_view, m.selected, m.scroll)),
        vb:multiline_text({
          width = "100%",
          height = 140,
          font = "mono",
          visible = prefs.show_tips.value,
          text = "\ntips : (hide in Tools/command_palette)\n\n" .. string:join(m.tips, "\n"),
        }),
      })
    end,
    update = function(m, msg, o)
      local s = renoise.song()
      local text_input = nil
      if s == nil then return end

      if msg == nil then
      -- TODO overwrite selected value with number, reset on move/filter
      -- elseif msg.type == "argument" then
      --   text_input = extend_text(m.text_input, msg.value)
      elseif msg.type == "text" then
        text_input = extend_text(m.text_input, msg.value)
      elseif msg.type == "delete" then
        text_input = m.text_input:sub(1, #m.text_input - 1)
      elseif msg.type == "nudge" then
        local p = m.list[m.selected]

        if p.type == "preset" then
          local d = options.device
          if #d.presets > 0 then
            d.active_preset = clamp(d.active_preset + sign(msg.value), 1, #d.presets)
          end
        elseif p.type == "header" then
          if options.instrument_index == nil then
            swap_devices_at(s.tracks[options.track_index], options.device_index, sign(msg.value))
            options.device_index =
              clamp(options.device_index + sign(msg.value), 2, #s.tracks[options.track_index].devices)
            s.selected_device_index = 1
            s.selected_device_index = options.device_index
          else
            swap_devices_at(
              s.instruments[options.instrument_index].sample_device_chains[options.chain_index],
              options.device_index,
              sign(msg.value)
            )

            options.device_index = clamp(
              options.device_index + sign(msg.value),
              2,
              #s.instruments[options.instrument_index].sample_device_chains[options.chain_index].devices
            )

            s.selected_sample_device_index = 1
            s.selected_sample_device_index = options.device_index
          end
        else
          local l = p.max - p.min
          local step = (l + 0.0) / (prefs.parameter_step_division.value + 0.0)
          if p.parameter.value_quantum == 0 then
            p.parameter.value = clamp(p.parameter.value + msg.value * step, p.min, p.max)
          else
            p.parameter.value = clamp(p.parameter.value + sign(msg.value), p.min, p.max)
          end
        end
      elseif msg.type == "toggle device" then
        -- local p = m.list[m.selected]
        if m.device_index > 1 then
          m.device.is_active = not m.device.is_active
        end
      elseif msg.type == "write param to pattern" then
        local p = m.list[m.selected]
        if p.device_index == nil then
        elseif p.device_index == 1 then
          -- TODO write P/L/W commands for 1 2 3
        else
          local l = s.selected_pattern_track:line(s.selected_line_index)
          write_parameter_to_line(s.selected_track, l, s.selected_effect_column_index, p.device_index - 1, p.parameter_index, p.parameter, true)
        end
      elseif msg.type == "set default value" then
        if m.list[m.selected].type == "preset" then
          local d = options.device
          if #d.presets > 0 then
            d.active_preset = 1
          end
        elseif m.list[m.selected].type == "header" then
        else
          local p = m.list[m.selected]
          p.parameter.value = p.default
        end
      elseif msg.type == "move" then
        local stepped =
          step_selected(msg.value, m.selected, m.scroll, m.list, prefs.wrapping.value, prefs.max_results.value)
        m.selected = stepped.selected
        m.scroll = stepped.scroll
        return CommandResult.continue
      elseif msg.type == "quit" then
        if prefs.escape_deletes.value and m.text_input ~= "" then
          text_input = ""
        else
          return CommandResult.quit
        end
      elseif msg.type == "next device container" then
        print(options.type)
        if options.type == "track device" then
        	options.track_index = clampwrap(options.track_index + msg.value, 1, #s.tracks, prefs.wrapping.value)
          s.selected_track_index = options.track_index
        	s.selected_track_device_index = 1
        	options.device = s.selected_track_device
        	options.device_index = 1
        	options.title = s.selected_track.name
        	parameter_palette(options)
          return CommandResult.quit
        elseif options.type == "sample device" then
          local nt = next_effect_chain(s, options.instrument_index, options.chain_index, msg.value)
          if nt ~= nil then
            options.instrument_index = nt.instrument
            options.chain_index = nt.chain
            s.selected_instrument_index = options.instrument_index
            s.selected_sample_device_chain_index = options.chain_index
            options.device_index = 1
            parameter_palette(options)
            return CommandResult.quit
          end
        end
      elseif msg.type == "next device" then
        o.callback = function()
          if options.type == "track device" then
            options.device_index =
              clampwrap(options.device_index + msg.value, 1, #s.selected_track.devices, prefs.wrapping.value)
            s.selected_track_device_index = options.device_index

            options.title = s.selected_track_device.short_name .. " @ " .. s.selected_track.name
            options.device = s.selected_track_device
            parameter_palette(options)
          else
            options.device_index = clampwrap(
              options.device_index + msg.value,
              1,
              #s.instruments[options.instrument_index].sample_device_chains[options.chain_index].devices,
              prefs.wrapping.value
            )
            s.selected_sample_device_index = options.device_index
            options.device = s.selected_sample_device
            options.title = s.selected_sample_device.short_name
              .. " @ "
              .. s.selected_instrument.name
              .. " / "
              .. s.selected_sample_device_chain.name
            parameter_palette(options)
          end
        end
        return CommandResult.quit
      elseif msg.type == "finish" then
        o.callback = function(_, _, _)
          local p = m.list[m.selected]
          if p.type == "preset" then
            pick_preset(options.device, function()
              parameter_palette(options)
            end).finish(renoise.song())
          elseif p.type == "header" then
            options.device.is_active = not options.device.is_active
            return CommandResult.continue
          else
            text_prompt(p.parameter.name .. " @ " .. options.device.short_name, function(t)
              p.parameter.value_string = t
              parameter_palette(options)
            end, p.parameter.value_string)
          end
        end
        return CommandResult.success
      end

      if text_input ~= nil then
        m.text_input = text_input
        local ls = ranked_matches(m.constant_list, m.text_input, function(item) return search_query(item.name) end)

        if #ls > 0 then
          m.list = ls
          index = 1
          m.selected = 1
          m.scroll = 0
        end
      end
      return CommandResult.continue
    end,

    keypress = function(e)
      local input_letter = to_letter(e)

      local msg = input_letter and message("text", input_letter) or nil

      if msg == nil then
        local input_number = tonumber(e.name, 10)
        if input_number == nil and e.name:sub(1, #"numpad numpad") == "numpad numpad" then
          input_number = tonumber(e.name:sub(#"numpad numpad" + 1))
        end
        msg = input_number and message("text", input_number .. "") or nil
      end

      if msg == nil then
        msg = match(e.name, {
          ["`"] = message("move", -1),
          tab = message("move", ifelse(e.modifiers == "shift", -1, 1)),
          down = match(e.modifiers, {
            alt = message("next device container", 1),
            option = message("next device container", 1),
            -- shift = message("next device", -1),
            -- control = message("nudge", -1),
            _ = message("move", 1),
          }),
          up = match(e.modifiers, {
            alt = message("next device container", -1),
            option = message("next device container", -1),
            -- shift = message("next device", -1),
            -- control = message("nudge", -1),
            _ = message("move", -1),
          }),
          left = match(e.modifiers, {
            alt = message("next device", -1),
            option = message("next device", -1),
            -- shift = message("next preset", -1),
            control = message("nudge", -1),
            _ = message("nudge", -16),
          }),
          right = match(e.modifiers, {
            alt = message("next device", 1),
            option = message("next device", 1),
            -- shift = message("next preset", 1),
            control = message("nudge", 1),
            _ = message("nudge", 16),
          }),
          esc = message("quit"),
          back = message("delete"),
          ["return"] = match(e.modifiers, {
            control = message("write param to pattern", 1),
            shift = message("toggle device", 1),
            alt = message("set default value", 1),
            option = message("set default value", 1),
            _ = message("finish"),
          }),
        })
      end

      -- if msg == nil then rprint(e) end
      return msg
    end,
  })
end

---@type fun(s:renoise.Song)
function open_parameter_palette(s)
  if tracks_visible() then
    -- show_frame("dsp")
    if s.selected_track_device_index == 0 then
      s.selected_track_device_index = 1
    end
    parameter_palette({
      title = s.selected_track_device.short_name .. " @ " .. s.selected_track.name,
      initial = 1,
      type = "track device",
      track_index = s.selected_track_index,
      device_index = s.selected_track_device_index,
      device = s.selected_track_device,
      get_list = function(options)
        local ls = get_track_dsp_parameters(options.track_index, options.device_index)
        table.insert(ls, 1, { type = "preset", name = "preset" })
        if s.selected_track_device_index > 1 then
          table.insert(ls, 1, { type = "header", name = "active bypass" })
        end
        return ls
      end,
    })
  else
    -- show_frame("effects")
    if s.selected_sample_device_chain_index == 0 then
      log("no sample fx chain to set parameters in")
      return
    end
    if s.selected_sample_device_index == 0 then
      s.selected_sample_device_index = 1
    end
    parameter_palette({
      title = s.selected_sample_device.short_name
        .. " @ "
        .. s.selected_instrument.name
        .. " / "
        .. s.selected_sample_device_chain.name,
      initial = 1,
      type = "sample device",
      instrument_index = s.selected_instrument_index,
      chain_index = s.selected_sample_device_chain_index,
      device_index = s.selected_sample_device_index,
      device = s.selected_sample_device,
      get_list = function(options)
        local ls = get_sample_dsp_parameters(options.instrument_index, options.chain_index, options.device_index)
        table.insert(ls, 1, { type = "preset", name = "preset" })
        if s.selected_sample_device_index > 1 then
          table.insert(ls, 1, { type = "header", name = "active bypass" })
        end

        return ls
      end,
    })
  end
end
