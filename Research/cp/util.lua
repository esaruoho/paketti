---@generic T
---@type fun(a:T, min:T, max:T):T
function clamp(a, min, max)
  return math.min(math.max(min, a), max)
end

---@generic T
---@type fun(a:T, min:T, max:T, allow_wrap:boolean):T
function clampwrap(a, min, max, allow_wrap)
  if allow_wrap then
    if a < min then
      return max - a
    elseif a > max then
      return min
    else
      return a
    end
  else
    return clamp(a, min, max)
  end
end

---@type fun(x:number):integer
function sign(x)
  if x < 0 then
    return -1
  else
    return 1
  end
end

---@generic T
---@type fun(self, t:T[], v:T):integer
function table:index_of(t, v)
  for i, k in pairs(t) do
    if k == v then
      return i
    end
  end
  return -1
end

---@generic T
---@type fun(self, t:T[], a:integer, b:integer):T[]
function table:swap(t, a, b)
  t[a], t[b] = t[b], t[a]
  return t
end

---@generic T
---@type fun(self, t:T[], f:fun(x:T):boolean):integer
function table:find_index(t, f)
  for i = 1, #t do
    if f(t[i]) then
      return i
    end
  end
  return 0
end

---@type fun(self, t:table):table
function table:reverse(t)
  local n, m = #t, #t / 2
  for i = 1, m do
    t[i], t[n - i + 1] = t[n - i + 1], t[i]
  end
  return t
end


---@generic T
---@type fun(self, t:T[], f:fun(x:T):boolean):T?
function table:find_by(t, f)
  for i = 1, #t do
    if f(t[i]) then
      return t[i]
    end
  end
  return nil
end

---@generic T
---@type fun(self, t:T[], f:fun(x:T):boolean):T[]
function table:filter(t, f)
  local ls = {}
  for _, k in pairs(t) do
    if f(k) then
      table.insert(ls, k)
    end
  end
  return ls
end

---@generic T
---@generic G
---@type fun(self, t:T[], transform:fun(x:T):G?):T[]
function table:filter_map(t, transform)
  local ls = {}
  for _, k in pairs(t) do
    local transformed = transform(k)
    if transformed ~= nil then
      table.insert(ls, transformed)
    end
  end
  return ls
end



---@type fun(value:integer, ls:{index:integer}):integer?
function clamp_in_list(value, ls)
  if ls == nil then
    return nil
  elseif #ls == 0 then
    return nil
  elseif #ls == 1 then
    return ls[1]
  else
    local last = ls[1].index
    for i = 2, #ls do
      if value < ls[i].index then
        return last
      end
      last = ls[i].index
    end
    return last
  end
end

---@type fun(v:integer):string
function midi_note(v)
  local notes = { "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-" }
  local n = v % 12
  local o = math.floor(v / 12)
  return notes[n + 1] .. o
end

---@generic T
---@generic G
---@type fun(self, ts:T[], f:fun(x:T, i:integer) : G ) : G[]
function table:map(ts, f)
  local ls = {}
  local i = 1
  for _, x in pairs(ts) do
    table.insert(ls, f(x, i))
    i = i + 1
  end
  return ls
end

---@type fun(source:string):string
function escape_lua_pattern(s)
  return (s:gsub("([%%%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"))
end

---@type fun(source:string):string
function search_query(s)
  return escape_lua_pattern(string.lower(s))
end

---@type fun(source:string):string
function trim(s)
  return s:match("^%s*(.-)%s*$")
end

---@type fun(source:string, e:string):string
function extend_text(s, e)
  if s == "" and e == " " then
    return ""
  else
    return s..e
  end
end

---@generic T
---@type fun(ts:T[], input:string, to_string:(fun(T):string)?):T[]
function ranked_matches(ts, input, to_string)
  if input == "" then
    return ts
  else
    local words = table:map(string:split(input, " "), search_query)
    if to_string == nil then
      to_string = search_query
    end
    local results = table:filter_map(ts, function(value)
      local ranked = nil
      for _, word in pairs(words) do
        local stringed = to_string(value)
        local rank = text_match(stringed, word)
        if rank == nil then
          return nil
        else
          if ranked == nil or rank > ranked.rank then
              ranked = {rank = rank, value = value, length = #stringed}
          end
        end
      end
      return ranked
    end)

    table.sort(results, function(a, b) return (a.rank == b.rank and a.length < b.length ) or a.rank < b.rank end)

    return table:map(results,
      function (r) return r.value
    end)
  end
end

---@generic T
---@type fun(self, t:T[], offset:integer):T[]
function table:scroll(t, offset)
  if offset == 1 then
    table.insert(t, #t, t[0])
    table.remove(t, 1)
  else
    table.insert(t, 1, t[0])
    table.remove(t, #t)
  end

  return t
end

---@type fun(source:string, query:string):integer?
function text_match(source, query)
  local s = string.lower(source)
  local q = string.lower(query)
  return (s:find(q))
end

---@type fun(string, s:string, separator:string):string[]
function string:split(s, separator)
  local a = {}
  for str in string.gmatch(s, "([^" .. separator .. "]+)") do
    table.insert(a, str)
  end
  if #a == 0 then
    return { s }
  else
    return a
  end
end

---@type fun(string, s:string[], separator:string):string
function string:join(strings, separator)
  local a = ""
  for i, s in pairs(strings) do
    if i == 1 then
      a = s
    else
      a = a .. separator .. s
    end
  end
  return a
end

---@type fun(v:integer, x:integer, l:integer):integer
function wrap(v, x, l)
  local r = ((v + x - 1) % l) + 1
  if x == -1 and v == 1 then
    r = l
  end
  return r
end

---@type fun(text:string):string
function capitalize_all(text)
  local words = string:split(text, " ")
  local capped = table:map(words, function(word)
    local l = word:gsub("^%l", string.upper)
    return l
  end)
  return string:join(capped, " ")
end

---@type fun(s:renoise.Song, sec:integer):integer
function section_end(s, sec)
  for i = sec + 1, #s.sequencer.pattern_sequence do
    if s.sequencer:sequence_is_start_of_section(i) then
      return i - 1
    end
  end
  return sec
end

---@type fun(start:integer):integer
function find_section_index(start)
  local i = start
  local q = renoise.song().sequencer
  while i > 0 do
    if q:sequence_is_start_of_section(i) then
      return i
    end
    i = i - 1
  end
  return 1
end


---@type fun(s:renoise.Song):{index:integer, name:string}[]
function get_sections(s)
  local ss = {}
  for i = 1, #s.sequencer.pattern_sequence do
    if s.sequencer:sequence_is_start_of_section(i) then
      table.insert(ss, { index = i, name = s.sequencer:sequence_section_name(i) })
    end
  end

  if #ss == 0 then
    return { { index = 1, name = "no sections" } }
  else
    return ss
  end
end

-- ---@type fun():{start_track:integer, end_track:integer, start_line:integer, end_line:integer}
-- function selection_in_matrix()
--   local song = renoise.song()
--   local seq = song.sequencer
--   local selection_range = function(start_track, start_line, end_track, end_line)
--     return {
--       start_track = start_track,
--       end_track = end_track,
--       start_line = start_line,
--       end_line = end_line,
--     }
--   end

--   local get_start = function()
--     for s = 1, #seq.pattern_sequence do
--       for t = 1, #song.tracks do
--         if seq:track_sequence_slot_is_selected(t, s) then
--           return selection_range(t, s, t, s)
--         end
--       end
--     end
--   end
--   local get_end = function(selection)
--     for s = #seq.pattern_sequence, 1, -1 do
--       for t = #song.tracks, selection.start_track, -1 do
--         if seq:track_sequence_slot_is_selected(t, s) then
--           return selection_range(selection.start_track, selection.start_line, t, s)
--         end
--       end
--     end
--     return selection
--   end

--   return get_end(get_start())
-- end

---@type fun(i:integer):string
function as_instrument_index(i)
  return string.upper(string.format("%02x", i - 1))
end

---@param get_list fun(i: renoise.Instrument):any[]
---@param get_item fun(i: renoise.Instrument, index: integer):any
---@param map_item fun(instrument_index: integer, overall_index:integer, sub_index: integer, item:any):any
---@return any[]
function find_all_instrument_items(get_list, get_item, map_item)
  local s = renoise.song()
  if s == nil then return {} end
  local ls = {}
  local overall_index = 1
  for i = 1, #s.instruments do
    local instrument = s:instrument(i)
    local target_list = get_list(instrument)
    for si = 1, #target_list do
      local item = get_item(instrument, si)
      table.insert(ls, map_item(i, overall_index, si, item))
      overall_index = overall_index + 1
    end
  end
  return ls
end

---@param instrument_index integer
---@param sub_index integer
---@param get_list fun(i: renoise.Instrument):any[]
---@return integer?
function find_instrument_item_index(instrument_index, sub_index, get_list)
  local s = renoise.song()
  if s == nil then return nil end
  local overall_index = 1
  for i = 1, #s.instruments do
    local instrument = s:instrument(i)
    if i == instrument_index then
      return overall_index + sub_index - 1
    else
      for _ = 1, #get_list(instrument) do
        overall_index = overall_index + 1
      end
    end
  end
  return nil
end

---@alias InstrumentIndexFinder fun(instrument_index:integer, sub_index:integer):integer?

---@type InstrumentIndexFinder
function find_phrase_index(instrument_index, phrase_index)
  return find_instrument_item_index(
    instrument_index,
    phrase_index,
    (function (i) return i.phrases end)
  )
end

---@type InstrumentIndexFinder
function find_sample_index(instrument_index, sample_index)
  return find_instrument_item_index(
    instrument_index,
    sample_index,
    (function (i) return i.samples end)
  )
end

---@alias InstrumentItemsFinder fun():any[]

---@type InstrumentItemsFinder
function get_all_samples()
  return find_all_instrument_items(
    (function(i) return i.samples end),
    (function(i, index) return i:sample(index) end),
    (function(i, overall_index, sub_index, item)
      return {
        instrument = i,
        index = overall_index,
        sample_index = sub_index,
        name = item.name,
        note = midi_note(item.sample_mapping.base_note),
      }
    end)
  )
end

---@type InstrumentItemsFinder
function get_all_phrases()
  return find_all_instrument_items(
    (function(i) return i.phrases end),
    (function(i, index) return i:phrase(index) end),
    (function(i, overall_index, sub_index, item)
      return {
        instrument = i,
        index = overall_index,
        phrase_index = sub_index,
        name = item.name,
      }
    end)
  )
end

---@type fun(instrument_index:integer, sample_index:integer):integer?
function find_sample_index(instrument_index, sample_index)
  local s = renoise.song()
  if s == nil then return nil end
  local overall_index = 1
  for i = 1, #s.instruments do
    local instrument = s:instrument(i)
    if i == instrument_index then
      return overall_index + sample_index - 1
    else
      for _ = 1, #instrument.samples do
        overall_index = overall_index + 1
      end
    end
  end
  return nil
end

---@type fun(device_data:{active:boolean}):string
function as_dsp_device_index(device_data)
  return (device_data.active and "#" or "-") --  .. device_data.device_index
end

---@type fun(track_index:integer, device_index:integer):integer
function find_track_device_index(track_index, device_index)
  local s = renoise.song()
  if s == nil then return 0 end
  local overall_index = 1
  for i = 1, #s.tracks do
    for di = 1, #s:track(i).devices do
      if i == track_index and di == device_index then
        return overall_index
      end
      overall_index = overall_index + 1
    end
  end
  return 1
end

---@alias SampleDevice { device_index:integer,index:integer,chain_index:integer,instrument_index:integer,name:string,active:boolean,type:"sample device",location_name:string}
---@alias TrackDevice { device_index:integer,index:integer,track_index:integer,name:string,active:boolean,type:"track device",location_name:string}

---@type fun(s:renoise.Song, device:SampleDevice|TrackDevice)
function select_dsp_device(s, device)
  if device.type == "track device" then
    show_frame("dsp")
    s.selected_track_index = device.track_index
    s.selected_track_device_index = device.device_index
  elseif device.type == "sample device" then
    show_frame("effects")
    s.selected_instrument_index = device.instrument_index
    s.selected_sample_device_chain_index = device.chain_index
    s.selected_sample_device_index = device.device_index
  end
end

---@type fun(container:renoise.Track|renoise.SampleDeviceChain, index:integer, dir:integer)
function swap_devices_at(container, index, dir)
  if dir < 0 then
    if index > 2 then
      container:swap_devices_at(index, index - 1)
    end
  else
    if index < #container.devices then
      container:swap_devices_at(index, index + 1)
    end
  end
end

---@type fun(instrument_index:integer, chain_index:integer, device_index:integer):integer
function find_sample_device_index(instrument_index, chain_index, device_index)
  local s = renoise.song()
  if s == nil then return 0 end
  local overall_index = 1
  for i = 1, #s.tracks do
    for _ = 1, #s:track(i).devices do
      overall_index = overall_index + 1
    end
  end

  for i = 1, #s.instruments do
    local instrument = s:instrument(i)
    for ci = 1, #instrument.sample_device_chains do
      local chain = instrument.sample_device_chains[ci]
      for di = 1, #chain.devices do
        if i == instrument_index and ci == chain_index and device_index == di then
          return overall_index
        end
        overall_index = overall_index + 1
      end
    end
  end

  return 1
end

---@return (SampleDevice|TrackDevice)[]
function get_all_dsp_devices()
  local ls = {}
  local s = renoise.song()
  if s == nil then return ls end
  local overall_index = 1
  for i = 1, #s.tracks do
    local track = s:track(i)
    for di = 1, #track.devices do
      local device = track.devices[di]
      table.insert(ls, {
        device_index = di,
        index = overall_index,
        track_index = i,
        name = device.short_name,
        active = device.is_active,
        location_name = track.name,
        type = "track device",
      })
      overall_index = overall_index + 1
    end
  end

  for i = 1, #s.instruments do
    local instrument = s:instrument(i)
    for ci = 1, #instrument.sample_device_chains do
      local chain = instrument.sample_device_chains[ci]
      for di = 1, #chain.devices do
        local device = chain.devices[di]
        table.insert(ls, {
          device_index = di,
          index = overall_index,
          chain_index = ci,
          instrument_index = i,
          name = device.short_name,
          active = device.is_active,
          type = "sample device",
          location_name = instrument.name .. " / " .. chain.name,
        })
        overall_index = overall_index + 1
      end
    end
  end
  return ls
end

---@type fun(v:number, a:number, b:number, na:number, nb:number):number
function remap(v, a, b, na, nb)
  local s = (nb - na) / (b - a)
  return na + s * (v - a)
end

---@type fun(device_index:integer):string
function device_string(device_index)
  if device_index < 10 then return tostring(device_index)..""
  elseif device_index <= 35 then return string.char(device_index + 55)
  else return "0" end
end

---@type fun(track:renoise.Track, line:renoise.PatternTrackLine, column_index:integer, device_index:integer, parameter_index:integer, p:renoise.DeviceParameter, add_columns_if_needed:boolean)
function write_parameter_to_line(track, line, column_index, device_index, parameter_index, p, add_columns_if_needed)
  local columns = track.visible_effect_columns
  local target = nil
  local target_string = device_string(device_index)..device_string(parameter_index)
  for e = 1, columns do
    local ec = line:effect_column(e)
    if ec.number_string == target_string then
      target = ec
    elseif (target == nil or e == column_index) and ec.is_empty then
      target = ec
    end
  end

  if target == nil and add_columns_if_needed then
    if columns < 8 then
      track.visible_effect_columns = columns + 1
      target = line:effect_column(columns + 1)
    end
  end

  if target ~= nil then
    target.number_string = target_string
    target.amount_value = math.floor(remap(p.value, p.value_min, p.value_max, 0, 255) + 0.5)
  end
end

---@alias SampleDeviceParameter {index:integer,name:string,min:number,max:number,default:number,value:number,value_string:string,parameter:renoise.DeviceParameter}
---@alias TrackDeviceParameter {index:integer,name:string,min:number,max:number,default:number,value:number,value_string:string,parameter:renoise.DeviceParameter,track_index:integer,device_index:integer,parameter_index:integer}

---@type fun(track_index:integer, device_index:integer):TrackDeviceParameter
function get_track_dsp_parameters(track_index, device_index)
  local ls = {}
  local s = renoise.song()
  if s == nil then return ls end
  for i = 1, #s.tracks[track_index].devices[device_index].parameters do
    local parameter = s.tracks[track_index].devices[device_index].parameters[i]
    table.insert(ls, {
      index = i,
      name = parameter.name,
      min = parameter.value_min,
      max = parameter.value_max,
      default = parameter.value_default,
      value = parameter.value,
      value_string = parameter.value_string,
      parameter = parameter,
      track_index = track_index,
      device_index = device_index,
      parameter_index = i,
    })
  end
  return ls
end

---@type fun(t:string)
function log(t)
  renoise.app():show_status("PAL : " .. t)
end

---@type fun(instrument_index:integer, chain_index:integer, device_index:integer):SampleDeviceParameter
function get_sample_dsp_parameters(instrument_index, chain_index, device_index)
  local ls = {}
  local s = renoise.song()
  if s == nil then return ls end
  local d = s.instruments[instrument_index].sample_device_chains[chain_index].devices[device_index]
  for i = 1, #d.parameters do
    local parameter = d.parameters[i]
    table.insert(ls, {
      index = i,
      name = parameter.name,
      min = parameter.value_min,
      max = parameter.value_max,
      default = parameter.value_default,
      value = parameter.value,
      value_string = parameter.value_string,
      parameter = parameter,
    })
  end
  return ls
end

---@type fun(i:renoise.Instrument):string
function get_instrument_name(i)
  return i.name
    .. (i.plugin_properties.plugin_device and " (" .. i.plugin_properties.plugin_device.short_name .. ") " or "")
end

---@generic T
---@type fun(x:string, ls:table<string, T>):T
function match_substrings(x, ls)
  for key, value in pairs(ls) do
    local matched = true
    for token in string.gmatch(key, "[^_]+") do
      if string.find(x, token) == nil then
        matched = false
        break
      end
    end
    if matched then
      return value
    end
  end
  return ls["_"]
end


---@generic K
---@generic T
---@type fun(x:K, ls:table<K, (fun())|T>):T?
function match(x, ls)
  for key, value in pairs(ls) do
    if x == key then
      return value
    end
  end
  return ls["_"]
end

---@generic T
---@type fun(c:boolean, r:T, e:T):T
function ifelse(c, r, e)
  if c then
    return r
  else
    return e
  end
end

function tryload(l)
  local success, lib = pcall(require, l)
  if success then
    return lib
  else
    return nil
  end
end

function include(dir, module)
  local path = "../" .. dir .. "/" .. module .. ".lua"
  local file = io.open(path, "rb")
  if file ~= nil then
    package.path = package.path .. ";" .. "../" .. dir .. "/?.lua"
    tryload(module)
    package.path = package.path .. ";./?.lua"
    -- return m
  end
  return nil

  -- else
  --   local message = path .. " not found!\n make sure you have " .. dir .. " installed!"
  --   renoise.app():show_prompt("missing dependecy!", message, {"OK"})
  -- end
end

---@alias ShowableFrame "matrix"|"pattern"|"sample"|"phrase"|"effects"|"modulation"|"keyzones"|"mixer"|"dsp"|"midi"|"plugin"

---@type fun(t:ShowableFrame)
function show_frame(t)
  local a = renoise.app()
  local w = a.window
  local show_middle = function(m)
    w.active_middle_frame = m
  end
  local _ = match(t, {
    matrix = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR)
      w.pattern_matrix_is_visible = true
    end,
    pattern = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR)
    end,
    sample = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR)
    end,
    phrase = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR)
    end,
    effects = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS)
    end,
    modulation = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION)
    end,
    keyzones = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES)
    end,
    mixer = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_MIXER)
      w.lower_frame_is_visible = true
    end,
    dsp = function()
      if
        w.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        or w.active_middle_frame ~= renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
      then
        show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR)
      end
      -- show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_MIXER)
      -- show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_MIXER)
      w.lower_frame_is_visible = true
      w.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
    end,
    midi = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR)
    end,
    plugin = function()
      show_middle(renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR)
    end,
  })()
end

---@type fun(frames:renoise.ApplicationWindow.MiddleFrame[]):boolean
function middle_frame_is(frames)
  for i = 1, #frames do
    if renoise.app().window.active_middle_frame == frames[i] then
      return true
    end
  end
  return false
end

---@type fun():boolean
function tracks_visible()
  return middle_frame_is({
    renoise.ApplicationWindow.MIDDLE_FRAME_MIXER,
    renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR,
  })
end

---@type fun():boolean
function sampler_visible()
  return middle_frame_is({
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR,
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR,
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES,
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS,
    renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION,
  })
end

---@type fun(p:integer):integer?
function find_sequence_index_with_pattern(p)
  local s = renoise.song()
  if s == nil then return 0 end
  for i = 1, #s.sequencer.pattern_sequence do
    if p == s.sequencer.pattern_sequence[i] then
      return i
    end
  end
  return nil
end

---@type fun(s:renoise.Song):integer
function current_beat(s)
  return math.floor((s.selected_line_index - 1) / s.transport.lpb)
end

---@type fun(s:renoise.Song, b:integer):integer
function beat_line(s, b)
  return (s.transport.lpb * b) + 1
end

---@type fun(s:integer, l:integer):renoise.SongPos
function song_pos(s, l)
  return renoise.SongPos(s, l)
end

---@type fun(seq:integer):integer
function lines_of(seq)
  local s = renoise.song()
  if s == nil then return 0 end
  return s:pattern(s.sequencer.pattern_sequence[seq]).number_of_lines
end

---@type fun(s:renoise.Song, seq:integer, line:integer, _seq:integer?, _line:integer?):integer?
function global_line(s, seq, line, _seq, _line)
  if seq > #s.sequencer.pattern_sequence then
    return nil
  end

  if _seq == nil then
    _seq = 1
    _line = 0
  end

  if _seq == seq then
    return _line + line
  else
    return global_line(s, seq, line, _seq + 1, _line + lines_of(_seq))
  end
end


---@type fun(s:renoise.Song):integer?
function song_length(s)
  local last = #s.sequencer.pattern_sequence
  return global_line(s, last, lines_of(last))
end

---@type fun(s:renoise.Song, line:integer, _seq:integer?):renoise.SongPos?
function local_line(s, line, _seq)
  if _seq == nil then
    _seq = 1
  end

  if line < 1 or line > song_length(s) or _seq > #s.sequencer.pattern_sequence then
    return nil
  end

  local seq_length = lines_of(_seq)
  if line <= seq_length then
    return song_pos(_seq, line)
  else
    return local_line(s, line - seq_length, _seq + 1)
  end
end

---@generic T
---@type fun(x:T?, def:T):T
function with_default(x, def)
  if x == nil then return def
  else return x end
end

---@type fun(s:renoise.Song, seq:integer, line:integer, offset:integer):renoise.SongPos?
function relative_line_in_song(s, seq, line, offset)
  local gl = global_line(s, seq, line)
  if gl == nil then return nil end
  local l = song_length(s)
  if l == nil then return nil end
  return local_line(s, clamp(gl + offset, 1, l))
end

---@type fun(s:renoise.Song, seq:integer, beat:integer, offset:integer):renoise.SongPos?
function relative_beat_in_song(s, seq, beat, offset)
  return relative_line_in_song(s, seq, beat_line(s, beat), s.transport.lpb * offset)
end

---@type fun(name: string) : string?
function get_device_type(path)
  local _, _, third = path:match("([^/]+)/([^/]+)/([^/]+)")
  return third
end
