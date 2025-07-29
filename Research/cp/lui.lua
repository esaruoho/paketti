require("constants")

function text_prompt(title, callback, text, width)
  local t = text or ""
  width = width or 200

  local vb = renoise.ViewBuilder()
  local margin = 15
  local name_dialog = nil
  local textfield = nil

  textfield = vb:textfield({
    edit_mode = true,
    width = width - margin * 2,
    text = t,
    notifier = function()
      name_dialog:close()
      callback(textfield.text)
    end,
  })

  local content = vb:row({
    width = width,
    margin = margin,
    textfield,
  })

  local key_handler = function(dialog, event)
    name_dialog:close()
    if event.name == "return" then
      callback(textfield.text)
    end
  end

  name_dialog = renoise.app():show_custom_dialog(title, content, key_handler)

  return textfield
end

function link_button(text, url)
  return renoise.ViewBuilder():button({
    text = text,
    pressed = function()
      renoise.app():open_url(url)
    end,
  })
end

function step_selected(dir, selected, scroll, list, wrap, rows)
  if dir < 0 then
    if scroll > 0 and selected == scroll + 2 then
      return { selected = selected - 1, scroll = scroll - 1 }
    elseif selected == 1 then
      if wrap then
        return { selected = #list, scroll = math.max(#list - rows, 0) }
      else
        return { selected = selected, scroll = scroll }
      end
    else
      return { selected = selected - 1, scroll = scroll }
    end
  elseif dir > 0 then
    if selected == #list then
      if wrap then
        return { selected = 1, scroll = 0 }
      else
        return { selected = selected, scroll = scroll }
      end
    elseif scroll < #list - rows and selected >= scroll + rows - 1 then
      return { selected = selected + 1, scroll = scroll + 1 }
    else
      return { selected = selected + 1, scroll = scroll }
    end
  end
end

function step_scroll(last, next, scroll, length)
  if last == next then
    return scroll
  end

  local scroll_delta = (scroll - 1) - last
  return clamp(
    next + scroll_delta,
    math.max(0, next - prefs.max_results.value),
    math.max(0, length - prefs.max_results.value)
  )
end

-- list : table of items
-- item_view : a function that turns an item into a table of vb:text elements
--             each element goes into a column to get nice alignment
-- selected_index : integer index of the selected item from the list
-- max_items : how many elements to show at once
-- space : space between list items
-- scroll : scroll position in the list
-- columns_count : number of columns (2 for most lists, 3 for device parameter palette)
function _list_view(list, item_view, selected_index, max_items, space, scroll, column_count)
  space = space and space or 1
  max_items = max_items and max_items or 7
  scroll = scroll and scroll or 0
  selected_index = math.max(1, math.min(selected_index, #list))
  column_count = column_count and column_count or 2

  local vb = renoise.ViewBuilder()

  local content = vb:horizontal_aligner({
    mode = "left",
    width = "100%",
    margin = 0,
  })
  if #list == 0 then
    return content
  end

  local columns = {}
  local tail_columns_width = function(index)
    if index < column_count then
      return nil
    else
      return "100%"
    end
  end

  for i = 1, column_count do
    local c = vb:column({
      width = tail_columns_width(i),
      spacing = space,
    })
    table.insert(columns, c)
    content:add_child(c)
  end

  local start = scroll + 1
  local ending = math.min(#list, start + max_items)
  for i = start, ending do
    if list[i] ~= nil then
      local items = item_view(list[i])
      for c = 1, #items do
        items[c].text = " " .. items[c].text .. " "
        columns[c]:add_child(vb:horizontal_aligner({
          mode = "left",
          width = "100%",
          vb:row({
            width = "100%",
            style = ifelse(i == selected_index, "plain", "invisible"),
            items[c],
          }),
        }))
      end
    end
  end
  return content
end

function list_view(list, item_view, selected_index, scroll)
  return _list_view(list, item_view, selected_index, prefs.max_results.value - 1, prefs.spacing.value, scroll, 2)
end

function list_view3(list, item_view, selected_index, scroll)
  return _list_view(list, item_view, selected_index, prefs.max_results.value - 1, prefs.spacing.value, scroll, 3)
end

function finder_list(o)
  o.name = o.title
  o.model = o.init(o.model)

  o.callback = function(result, m, o) end

  local vb = renoise.ViewBuilder()
  o.view_container = vb:column({
    width = prefs.width.value,
  })
  o.has_view = false

  o.render = function(m)
    if o.has_view then
      o.view_container:remove_child(o.model_view)
      o.has_view = false
    end
    o.model_view = o.view(o.model)
    o.has_view = true
    o.view_container:add_child(o.model_view)
  end

  o.process = function(m, msg, o)
    local result = o.update(m, msg, o)
    if result == CommandResult.continue then
      o.render(m)
    else
      if o.window.visible then
        o.window:close()
      end
      if o.callback then
        o.callback(result, o.model, o)
      end
      o = nil
    end
  end
  o.key_down = function(target, event)
    local msg = o.keypress(event, o.model, o)
    o.process(o.model, msg, o)
  end

  o.update(o.model, message("init", 0))
  o.render(o.model)

  o.window = renoise.app():show_custom_dialog(o.title, o.view_container, o.key_down)

  return o
end
