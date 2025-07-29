require("constants")

---@type fun(options:CommandOptions):State
function argument_palette(options)
  local initial = options.initial
  if type(initial) == "function" then
    initial = initial(renoise.song())
  end
  local model = {
    title = ifelse(prefs.ninja_mode.value, "", text_transform(options.title)),
    width = prefs.width.value,

    get_list = options.get_list,
    base_command = options.base_command,
    initial = initial,

    untouched = true,
    text_input = "",

    selected = initial,
    scroll = 0,
    list = options.get_list(options.base_command),
    constant_list = options.get_list(options.base_command),
  }

  model.scroll = clamp(model.selected - 2, 0, math.max(#model.list - prefs.max_results.value, 0))

  local item_view = options.item_view and options.item_view
    or function(item)
      return {
        soft_text(item.alias and item.alias or ""),
        raw_text(item.name),
      }
    end

  return finder_list({
    title = model.title,
    model = model,
    callback = function(result, m, o)
      local song = renoise.song()
      if result == CommandResult.success then
        local command = m.list[m.selected]
        local arg = command.validate and command.validate(song, m.argument) or m.argument
        table.insert(History, command_call(m.base_command.alias, arg))
      end
    end,
    finish = options.finish and options.finish or function(m) end,
    init = options.init and options.init or function(m)
      local song = renoise.song()
      m.untouched = true
      return m
    end,
    view = function(m)
      local vb = renoise.ViewBuilder()
      local command = m.selected > 0 and m.list[m.selected] or nil
      local alias = command and m.list[m.selected].alias or ""
      return vb:column({
        width = "100%",
        vb:row({
          vb:button({
            text = (command and command.bind) and command.bind or alias,
          }),
          vb:text({
            font = text_font(),
            text = ifelse(m.text_input == alias, "", m.text_input),
            visible = m.text_input == alias or #m.text_input > 0,
          }),
        }),
        ifelse(prefs.ninja_mode.value, nil, list_view(m.list, item_view, m.selected, m.scroll)),
      })
    end,
    update = function(m, msg, o)
      m.selected = clamp(m.selected, 1, #m.list)
      local touchfirst = function()
        if m.untouched then
          m.untouched = false
          m.text_input = ""
          return true
        else
          return false
        end
      end

      local command_by_alias = function(list, alias)
        return table:find_by(list, function(c)
          return (c.bind and (c.bind == alias)) or c.alias == alias
        end)
      end

      local song = renoise.song()
      local text_input = nil
      if msg == nil then
      elseif msg.type == "text" then
        touchfirst()
        text_input = extend_text(m.text_input, msg.value)
        local c = command_by_alias(m.list, m.text_input)
        if c ~= nil then
          local i = table:find_index(m.list, function(_c)
            return _c.alias == c.alias or _c.bind == c.alias
          end)
          if i ~= 0 then
            m.scroll = step_scroll(m.selected, i, m.scroll, #m.list)
            m.selected = i
            m.initial = c.init(renoise.song())
          end
        end

        c = c and c or m.list[m.selected]
        local arg = c.validate and c.validate(song, m.argument) or m.argument
        local result = c.run(song, arg)
      elseif msg.type == "delete" then
        text_input = m.text_input:sub(1, #m.text_input - 1)
      elseif msg.type == "move" then
        local stepped =
          step_selected(msg.value, m.selected, m.scroll, m.list, prefs.wrapping.value, prefs.max_results.value)
        m.selected = stepped.selected
        m.scroll = stepped.scroll

        local c = m.list[m.selected]
        local arg = c.validate and c.validate(song, m.argument) or m.argument
        local result = c.run(song, arg)
        return CommandResult.continue
      elseif msg.type == "quit" then
        local command = m.list[m.selected]
        if command then
          command.cancel(song, m.initial)
        end
        return CommandResult.quit
      elseif msg.type == "finish" then
        o.callback = function(result, m, o)
          local command = m.list[m.selected]
          local arg = command.validate and command.validate(song, m.argument) or (m.argument and m.argument or 1)
          local result = command.run(song, arg)
          if result == nil then
            command.finish(renoise.song(), arg)
            table.insert(History, 1, command_call(m.base_command.alias, arg - 1))
          elseif #result > 0 then
            -- print(result)
          else
          end
        end

        return CommandResult.success
      end

      if text_input ~= nil then
        m.text_input = text_input
        local ls = ranked_matches(m.constant_list, m.text_input, command_as_string)

        if #ls > 0 then
          m.list = ls

          local index = 1
          m.scroll = step_scroll(m.selected, index, m.scroll, #m.list)
          m.selected = index
        end
      end
      local c = m.list[m.selected]
      if c == nil then return CommandResult.quit end
      if c.name ~= "" then
        local arg = c.validate and c.validate(song, m.argument) or m.argument
        local result = c.run(song, arg)
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
          down = message("move", 1),
          ["`"] = message("move", -1),
          tab = message("move", ifelse(e.modifiers == "shift", -1, 1)),
          up = message("move", -1),
          esc = message("quit"),
          back = message("delete"),
          ["return"] = message("finish"),
        })
      end

      -- if msg == nil then rprint(e) end
      return msg
    end,
  })
end
