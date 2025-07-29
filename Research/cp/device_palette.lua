require("lui")

---@alias DeviceContainer "track"|"modulation"|"sample"

---@class DeviceEntry
---@field name string
---@field path string
---@field preset_index integer?
---@field type string?

---@type {sample: DeviceEntry[], modulation: DeviceEntry[], track: DeviceEntry[]}
local devices_lists = {
  sample = {},
  modulation = {},
  track = {}
}

local function get_modulation_device_name(n)
  local ns = string:split(n, "/")
  return ns[#ns]
end

---@type fun(device_type:DeviceContainer, target: renoise.Track | renoise.SampleDeviceChain | renoise.SampleModulationSet) : DeviceEntry[]
local function get_device_list(device_type, target)
  local list = devices_lists[device_type]
  if #list ~= 0 then
    return list
  end

  if device_type == "sample" or device_type == "track" then
    target = renoise.song().selected_track

    local device_infos = target.available_device_infos
    table:reverse(device_infos)

    for i = 1, #device_infos do
      local d = {
        name = device_infos[i].favorite_name,
        path = device_infos[i].path,
        type = get_device_type(device_infos[i].path)
      }

      table.insert(list, d)

      if (device_type == "sample" or device_type == "track") and d.path == "Audio/Effects/Native/Doofer" then
        local song = renoise.song()
        if song == nil then break end
        song.selected_track:insert_device_at(device_infos[i].path, 2)
        local presets = {}
        for pi = 2, #song.selected_track.devices[2].presets do
          local preset = song.selected_track.devices[2].presets[pi]
          d = {
            type = "Doofer",
            name = preset,
            preset_index = pi,
            path = device_infos[i].path,
          }
          table.insert(list, d)
        end

        song.selected_track:delete_device_at(2)
      end
    end
  else
    local devices = target.available_devices
    for i = 1, #devices do
      table.insert(list, {
        name = get_modulation_device_name(devices[i]),
        path = devices[i],
        type = ""
      })
    end
  end

  table.sort(list, function(a, b) return search_query(a.name) < search_query(b.name) end )
  return list
end

---@type fun(device_type:DeviceContainer, subtype:renoise.SampleModulationDevice.TargetType?)
function open_device_palette(device_type, subtype)
  local s = renoise.song()
  if s == nil then return end

  ---@type fun(t:DeviceContainer):renoise.SampleDeviceChain|renoise.SampleModulationSet|renoise.Track
  local find_target = function(t)
    return match(t, {
      track = function()
        return s.selected_track
      end,
      modulation = function()
        show_frame("modulation")
        -- it is possible that the user selected None as modulation set
        -- we'll use the first modulation set in that case
        -- and ensure there is at least one set
        if s.selected_sample_modulation_set == nil then
          if #s.selected_instrument.sample_modulation_sets == 0 then
            s.selected_instrument:insert_sample_modulation_set_at(1)
          end
          s.selected_sample_modulation_set_index = 1
        end
        return s.selected_sample_modulation_set
      end,
      sample = function()
        if s.selected_sample_device_chain == nil then
          s.selected_instrument:insert_sample_device_chain_at(1)
        end
        return s.selected_sample_device_chain
      end,
    })
  end

  ---@type fun(t:DeviceContainer, index:integer)
  local set_preset = function(t, index)
    return match(t, {
      track = function()
        s.selected_track_device.active_preset = index
      end,
      sample = function()
        s.selected_sample_device.active_preset = index
      end,
    })()
  end


  ---@type fun(t:DeviceContainer, path:string)
  local insert_device = function(t, path)
    return match(t, {
      track = function()
        local i = s.selected_device_index + 1
        if i == 0 or i == 1 or i == nil then
          i = math.max(2, #s.selected_track.devices)
        end
        local device = s.selected_track:insert_device_at(path, i)
        s.selected_device_index = i
      end,
      modulation = function()
        local i = #s.selected_sample_modulation_set.devices + 1
        if i == 0 or i == 1 or i == nil then
          i = math.max(1, #s.selected_sample_modulation_set.devices)
        end
        s.selected_sample_modulation_set:insert_device_at(path, subtype, i)
      end,
      sample = function()
        local i = s.selected_sample_device_index + 1
        if i == 0 or i == 1 or i == nil then
          i = math.max(2, #s.selected_sample_device_chain.devices)
        end
        local device = s.selected_sample_device_chain:insert_device_at(path, i)
        s.selected_sample_device_index = i
      end,
    })
  end

  ---@type fun(item:DeviceEntry):table<renoise.Views.View>
  local item_view = function(item)
    return {
      soft_text(item.type),
      raw_text(item.name),
    }
  end


  local window = finder_list({
    title = text_transform("device palette"),
    model = {
      title = "device palette",
      selected = 0,
      scroll = 0,
      list = {},
      width = 0,
      sign = 1,
      constant_list = {},
      history = {},
      history_pos = 0,
      untouched = true,
      text_input = "",
      get_list = function ()
        return {}
      end
    },
    init = function(m)
      local t = find_target(device_type)()
      if t then
        local constant_list = get_device_list(device_type, t)
        local list = {}
        for i = 1, #constant_list do
          table.insert(list, constant_list[i])
        end
        m.constant_list = constant_list
        m.list = list
      end
      return m
    end,
    -- callback = callback,
    update = function(m, msg)
      if m.selected == 0 then
        m.selected = 1
      end
      if msg == nil then
        return CommandResult.continue
      end
      local text_input = nil
      if msg.type == "quit" then
        if prefs.escape_deletes.value and m.text_input ~= "" then
          text_input = ""
        else
          return -1
        end
      elseif msg.type == "argument" then
        text_input = extend_text(m.text_input, msg.value)
      elseif msg.type == "text" then
        text_input = extend_text(m.text_input, msg.value)
      elseif msg.type == "delete" then
        text_input = m.text_input:sub(1, #m.text_input - 1)
      elseif msg.type == "move" then
        local stepped =
          step_selected(msg.value, m.selected, m.scroll, m.list, prefs.wrapping.value, prefs.max_results.value)

        m.selected = stepped.selected
        m.scroll = stepped.scroll
      elseif msg.type == "finish" then
        local s = renoise.song()
        local d = m.list[clamp(m.selected, 1, #m.list)]
        if d == nil then
          return CommandResult.quit
        else
          local path = d.path
          insert_device(device_type, path)()

          if d.preset_index then
            set_preset(device_type, d.preset_index)
          end

          return 1
        end
      end
      local index = m.selected
      if text_input ~= nil then
        m.text_input = text_input
        local ls = ranked_matches(m.constant_list, m.text_input, function (d)
          return search_query(d.name).." "..(d.type and search_query(d.type) or "")
        end)

        if #ls > 0 then
          m.list = ls
        end
        index = 1
      end
      m.scroll = step_scroll(m.selected, index, m.scroll, #m.list)
      m.selected = index
      return CommandResult.continue
    end,

    view = function(m)
      local vb = renoise.ViewBuilder()
      return vb:column({
        width = "100%",
        vb:row({
          vb:button({
            text = "$ : ",
          }),
          raw_text(m.text_input),
        }),
        list_view(m.list, item_view, m.selected, m.scroll),
      })
    end,
    keypress = function(e)
      local input_letter = to_letter(e)
      local msg = input_letter and message("text", input_letter) or nil
      if msg == nil then
        local input_number = tonumber(e.name, 10)
        if input_number == nil and e.name:sub(1, #"numpad numpad") == "numpad numpad" then
          input_number = tonumber(e.name:sub(#"numpad numpad" + 1))
        end
        msg = input_number and message("argument", input_number) or nil
      end

      if msg == nil then
        msg = match(e.name, {
          ["`"] = message("move", -1),
          tab = message("move", ifelse(e.modifiers == "shift", -1, 1)),
          down = message("move", 1),
          up = message("move", -1),
          esc = message("quit"),
          back = message("delete"),
          ["return"] = message("finish"),
        })
      end

      return msg
    end,
  })
end
