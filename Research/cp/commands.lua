require("command")
require("device_palette")
require("parameter_palette")
-- require "finder_pal"

---@type fun(device: renoise.TrackDevice, callback: function?):Command
local function pick_preset(device, callback)
  local c = action_finder_command(
    "pret",
    "preset for track dsp device",
    -- function(s, n)
    --   return clamp(n + 1, 1, #device.presets)
    -- end,
    {
      -- export = function(s)
      --   if device then
      --     return device.active_preset
      --   end
      -- end,
      get_list = function(command)
        local song = renoise.song()
        local list = table:map(device.presets, function(p, i)
          local select_preset = function(s, n)
            device.active_preset = i
          end
          local finish_selection = function(s, n)
            select_preset(s, n)
            if callback then
              callback()
            end
          end
          local options = {
            init = select_preset,
            validate = select_preset,
            run = select_preset,
          }
          return action_command(p .. "", device.presets[i], finish_selection, options)
        end)
        return list
      end,
    }
  )
  return c
end

---@type fun(alias:string, type:string):Command
local function toggle_column(alias, type)
  return action_command(alias, "toggle "..type.." column", function(s, n)
    local k = type.."_column_visible"
    if s.selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      s.selected_track[k] = not s.selected_track[k]
    end
  end)
end

commands = {
  number_command("_", "go to line", "selected_line_index", function(s, n)
    return clamp(n + 1, 1, s.selected_pattern.number_of_lines)
  end),

  number_command("b", "go to beat", "selected_line_index", function(s, n)
    if n <= 0 then
      return s.selected_line_index
    else
      return clamp(s.transport.lpb * (n - 1) + 1, 1, s.selected_pattern.number_of_lines)
    end
  end),

  number_finder_command("i", "select instrument", "selected_instrument_index", function(s, n)
    return clamp(n + 1, 1, #s.instruments)
  end, {
    export = function(s)
      return s.selected_instrument_index
    end,
    get_list = function(command)
      local list = table:map(renoise.song().instruments, function(instrument, i)
        return number_command(as_instrument_index(i), get_instrument_name(instrument), command.target, function(s, n)
          return i
        end)
      end)
      return list
    end,
  }),

  -- number_finder_command(
  --   "loop",
  --   "set sample loop",
  --   "selected_sample.loop_mode",
  --   function(s, n)
  --   	if n == 0 then
  --   		s.selected_sample.loop_release = false
  --   	else
  --   		s.selected_sample.loop_release = true
  --   	end
  --   	return clamp(n, 0, 2)
  --   end,

  --   {
  --   	export = function(s)
  --   		return s.selected_sample.loop_mode
  --   	end,
  --   	get_list = function(command)
  --   		local list = {}
  --   		for i = 0, 2 do
  --   			table.insert(list, number_command(i.."", ))
  --   		end
  -- 	  	  return number_command(i.."", loop_names[i], command.target, function(s,n) return i end) end)
  -- 	  	return list
  -- 	  end,
  --   }
  -- ),

  action_finder_command("pl", "load plugin", {
    validate = function(s, n)
      return n
    end,
    get_list = function(command)
      local list = table:map(
        renoise.song().selected_instrument.plugin_properties.available_plugin_infos,
        function(plug, _)
          return { name = plug.short_name, path = plug.path, type = get_device_type(plug.path) }
        end
      )

      table.insert(list, 1, { name = "None", path = "" })

      return table:map(list, function(plug, i)
        return action_command(plug.type and plug.type or " ", plug.name, function(s, n)
          s.selected_instrument.plugin_properties:load_plugin(plug.path)
          return i
        end)
      end)
    end,
  }),

  action_command("upl", "unload plugin", function(s, n)
    s.selected_instrument.plugin_properties:load_plugin("")
  end),


  number_finder_command("t", "select track", "selected_track_index", function(s, n)
    return clamp(n, 1, #s.tracks)
  end, {
    get_list = function(command)
      local list = table:map(renoise.song().tracks, function(track, i)
        return number_command(i .. "", track.name, command.target, function(s, n)
          return i
        end)
      end)
      return list
    end,
  }),

  toggle_command("tc", "toggle track collapse", "selected_track.collapsed"),
  action_command("gc", "toggle group collapse", function(s, n)
    local t = s.selected_track
    if t.group_parent ~= nil then
      t.group_parent.group_collapsed = not t.group_parent.group_collapsed
    elseif t.type == renoise.Track.TRACK_TYPE_GROUP then
      if #t.members > 0 then
        t.members[1].group_parent.group_collapsed = not t.members[1].group_parent.group_collapsed
      else
        t.collapsed = not t.collapsed
      end
    end
  end
  ),

  action_finder_command(
    "d",
    "select DSP device",
    -- "selected_track_device_index",
    -- function(s, n)
    -- return clamp(n, 2, #s.selected_track.devices)
    -- end,
    {
      initial = function(s)
        if tracks_visible() then
          local i = find_track_device_index(s.selected_track_index, s.selected_track_device_index)
          return i
        else
          local i = find_sample_device_index(
            s.selected_instrument_index,
            s.selected_sample_device_chain_index,
            s.selected_sample_device_index
          )
          return i
        end
      end,
      -- init = function(s)
      -- 	select_dsp_device
      get_list = function(_)
        local list = get_all_dsp_devices()
        -- rprint(list)
        list = table:map(list, function(device, _)
          local select_device = function(s)
            select_dsp_device(s, device)
          end

          return action_command(
            device.location_name .. " " .. as_dsp_device_index(device),
            device.name,
            -- function(s,n)
            -- 	return i
            -- end,
            function(s, _)
              select_device(s)
              open_parameter_palette(s)
            end,
            {
              init = select_device,
              validate = select_device,
              run = select_device,
              cancel = function()
                return
              end,
            }
          )
        end)
        return list
      end,
    }
  ),

  action_command("par", "set parameters on dsp device", function(s, n)
    open_parameter_palette(s)
  end),

  number_finder_command("sa", "select sample", "selected_sample_index", function(s, n)
    return clamp(n, 1, #s.selected_instrument.samples)
  end, {
    initial = function(s)
      local i = find_sample_index(s.selected_instrument_index, s.selected_sample_index)
      return i
    end,
    get_list = function(command)
      local list = get_all_samples()
      return table:map(list, function(ins, i)
        return number_command(
          as_instrument_index(ins.instrument) .. " " .. ins.note .. "",
          ins.name,
          command.target,
          function(s, n)
            return i
          end,
          {
            cancel = function(s, initial)
              s.selected_instrument_index = list[initial].instrument
              s.selected_sample_index = list[initial].sample_index
              -- show_frame("sample")
              return nil
            end,
            run = function(s, arg, initial)
              arg = arg and arg or 1

              -- if not sampler_visible() then
              -- 	show_frame("sample")
              -- end

              s.selected_instrument_index = list[arg].instrument
              s.selected_sample_index = list[arg].sample_index
              -- show_frame("sample")
              return nil
            end,
          }
        )
      end)
    end,
  }),

  number_finder_command("se", "select section", "selected_sequence_index", function(s, n)
    local ls = get_sections(s)
    local v = ls[clamp(n, 1, #ls)] and ls[clamp(n, 1, #ls)].index or 1
    return clamp(v, 1, #s.sequencer.pattern_sequence)
  end, {
    init_palette = function(m)
      local song = renoise.song()
      m.untouched = true
      m.selected = find_section_index(m.initial)
      -- m.initial = find_section_index(m.initial)
      m.initial = m.selected
      return m
    end,

    export = function(s)
      return find_section_index(s.selected_sequence_index)
    end,
    -- init = function(s)
    -- 	return find_section_index(s.selected_sequence_index)
    -- end,
    get_list = function(command)
      local list = get_sections(renoise.song())
      return table:map(list, function(section, i)
        return number_command(section.index .. "", section.name, command.target, function(s, n)
          show_frame("matrix")
          return section.index
        end)
      end)
    end,
  }),

  number_finder_command("s", "select sequence index", "selected_sequence_index", function(s, n)
    return clamp(n + 1, 1, #s.sequencer.pattern_sequence)
  end, {
    initial = function(s)
      return s.selected_sequence_index
    end,
    get_list = function(command)
      local song = renoise.song()
      return table:map(song.sequencer.pattern_sequence, function(si, i)
        -- i = i + 1
        local name = song.sequencer:sequence_is_start_of_section(i) and song.sequencer:sequence_section_name(i) or ""
        return number_command(
          (#song.patterns[si].name > 0 and song.patterns[si].name or (si - 1) .. ""),
          name,
          command.target,
          function(s, n)
            return clamp(si, 1, #s.sequencer.pattern_sequence)
          end,
          {
            finish = function(song, model, o)
              table.insert(History, 1, command_call(command.alias, si - 1))
              return nil
            end,
          }
        )
      end)
    end,
  }),

  number_finder_command("f", "select phrase", "selected_phrase_index", function(s, n)
    return clamp(n, 0, #s.selected_instrument.phrases)
  end, {
    initial = function(s)
      local i = find_phrase_index(s.selected_instrument_index, s.selected_phrase_index)
      return i
    end,
    get_list = function(command)
      local list = get_all_phrases()
      return table:map(list, function(ins, i)
        return number_command(
          as_instrument_index(ins.instrument),
          ins.name,
          command.target,
          function(s, n)
            return i
          end,
          {
            cancel = function(s, initial)
              s.selected_instrument_index = list[initial].instrument
              s.selected_phrase_index = list[initial].phrase_index
              -- show_frame("sample")
              return nil
            end,
            run = function(s, arg, initial)
              arg = arg and arg or 1

              -- if not sampler_visible() then
              -- 	show_frame("sample")
              -- end

              s.selected_instrument_index = list[arg].instrument
              s.selected_phrase_index = list[arg].phrase_index
              -- show_frame("sample")
              return nil
            end,
          }
        )
      end)
    end,
  }),

  number_command("hr", "set headroom", "transport.track_headroom", function(s, n)
    return math.db2lin(clamp(n, -12, 0))
  end
  ),

  number_command("pat", "set pattern in sequence", "selected_pattern_index", function(s, n)
    return clamp(n + 1, 0, 999)
  end),

  number_finder_command("p", "select pattern", "selected_sequence_index", function(s, n)
    return find_sequence_index_with_pattern(clamp(n + 1, 1, 999))
  end, {
    get_list = function(command)
      local song = renoise.song()
      local list = {}
      for i = 1, #song.patterns do
        local p = song:pattern(i)
        local index = find_sequence_index_with_pattern(i)
        if index then
          table.insert(
            list,
            number_command((i - 1) .. "", p.name, command.target, function(song, n)
              return index
            end, {
              -- function(s, n) return clamp(find_sequence_index_with_pattern(i), 1, #s.sequencer.pattern_sequence) end,  {
              run = function(s, arg, initial)
                arg = arg and arg or 1
                -- local list = get_all_samples()
                s.selected_sequence_index = clamp(index, 1, #s.sequencer.pattern_sequence)
                -- s.selected_instrument_index = list[arg].instrument
                -- s.selected_sample_index = list[arg].sample_index
                -- show_frame("sample")
                return nil
              end,
            })
          )
        end
      end
      -- rprint(list)
      return list
    end,
  }),

  number_command("bpm", "set BPM - beats per minute", "transport.bpm", function(s, n)
    return clamp(n, 32, 999)
  end),

  number_command("lpb", "set LPB - lines per beat", "transport.lpb", function(s, n)
    return clamp(n, 1, 512)
  end),

  number_command("v", "set velocity", "transport.keyboard_velocity", function(s, n)
    if n == 128 then
      s.transport.keyboard_velocity_enabled = false
      return s.transport.keyboard_velocity
    else
      s.transport.keyboard_velocity_enabled = true
      return clamp(n, 0, 128)
    end
  end),

  toggle_command("tv", "toggle keyboard velocity", "transport.keyboard_velocity_enabled"),

  number_command("tpl", "set TPL - ticks per line", "transport.tpl", function(s, n)
    return clamp(n, 1, 16)
  end),

  number_command("o", "set octave", "transport.octave", function(s, n)
    return clamp(n, 0, 8)
  end),

  number_command("e", "set edit step", "transport.edit_step", function(s, n)
    return clamp(n, 0, 64)
  end),

  number_command("qua", "set record quantize", "transport.record_quantize_lines", function(s, n)
    if n == 0 then
      s.transport.record_quantize_enabled = false
    else
      s.transport.record_quantize_enabled = true
    end
    return clamp(n, 1, 32)
  end),

  new_command(
    CommandType.custom,
    "qb",
    "loop beats from position",
    function(s)
      return {
        looping = s.transport.loop_block_enabled,
        range = s.transport.loop_range
      }
    end,
    function(s, n)
      if n == nil then n = 1 end
      if(n == 0) then
        s.transport.loop_block_enabled = false
      else
        local bi = current_beat(s)
        local a = relative_beat_in_song(s, s.selected_sequence_index, bi, 0)
        local b = relative_beat_in_song(s, s.selected_sequence_index, bi, n)

        -- if the loop's end is at the end of the whole song we need to set an otherwise non-existent line index
        if b.sequence == #s.sequencer.pattern_sequence and b.line == lines_of(#s.sequencer.pattern_sequence) then
          b.line = b.line + 1
        end

        s.transport.loop_range = { a, b }

        if s.transport.playing and prefs.schedule_loops_when_playing.value then
          s.transport:start_at(a)
        end
      end
    end,
    function(s, arg, m) end,
    function(s, initial)
      s.transport.loop_block_enabled = initial.looping
      s.transport.loop_range = initial.range
    end
  ),

  number_command("qs", "loop sequence(s) from position", "transport.loop_sequence_range", function(s, n)
    if type(n) == "table" then
      return n
    elseif n == 0 or n == nil then
      return {}
    else
      local i = s.selected_sequence_index
      local ni = clamp(i + n + -1 * sign(n), 1, s.transport.song_length.sequence)
      local loop_start = math.min(i, ni)
      local loop_end = math.max(i, ni)
      -- if s.transport.playing and prefs.schedule_loops_when_playing.value then
      --   -- s.transport:set_scheduled_sequence(loop_start)
      -- else
      --   -- s.transport:start_at(renoise.SongPos(loop_start, 1))
      -- end

      return { loop_start, loop_end }
    end
  end),

  action_command(
    "qe",
    "loop selection",
    function(s, n)
      local se = s.selection_in_pattern
      if se == nil then 
        return nil
      else
        s.transport.loop_range = {
          song_pos(s.selected_sequence_index, se.start_line),
          song_pos(s.selected_sequence_index, se.end_line + 1)
        }
      end
    end
  ),

  number_command("qf", "set block loop size fraction", "transport.loop_block_range_coeff", function(s, n)
    return clamp(n, 2, 16)
  end),

  toggle_command("qt", "toggle block loop", "transport.loop_block_enabled"),

  -- action_finder_command(
  --   "lse",
  --   "loop section",
  --   -- "transport.loop_sequence_range",
  --   -- function(s, n)
  --   -- 	local ss = get_sections(s)

  --   --   local i = s.selected_sequence_index
  --   --   local ni = clamp(i + n + -1 * sign(n), 1, s.transport.song_length.sequence)
  --   --   local loop_start = math.min(i, ni)
  --   --   local loop_end = math.max(i, ni)
  --   --   if s.transport.playing and prefs.schedule_loops_when_playing.value then
  --   --     s.transport:set_scheduled_sequence(loop_start)
  --   --   else
  --   --     s.transport:start_at(renoise.SongPos(loop_start, 1))
  --   --   end

  --   --   return { loop_start, loop_end }
  --   -- 	-- local ls = get_sections(s)
  --   -- 	-- return clamp(ls[clamp(n, 1, #ls)].index, 1, #s.sequencer.pattern_sequence)
  --   -- end,
  --   {
  --   	validate = function(s, n) return n end,
  --   	-- export = function(s)
  --   	-- 	return nil
  --   	-- end,
  --   	get_list = function(command)
  -- 	  	local list = table:map(renoise.song().selected_instrument.plugin_properties.available_plugin_infos, function(plug, i)
  -- 	  	  -- oprint(plug)
  -- 	  	  -- local name = string:split(plug, "/")name[#name]
  -- 	  	  return action_command(i.."", plug.short_name, function(s,n)
  -- 	  	      s.selected_instrument.plugin_properties:load_plugin(plug.path)
  -- 	  	    	return i
  -- 	  	    end
  -- 	  	  ) end)
  -- 	  	-- rprint(list)
  -- 	  	return list
  -- 	  end,
  --   }
  -- ),

  --   	init_palette = function(m)
  -- 			local song = renoise.song()
  -- 			m.untouched = true
  -- 			m.selected = find_section_index(m.initial)
  -- 			-- m.initial = find_section_index(m.initial)
  -- 			m.initial = m.selected
  -- 			return m
  --   	end,

  --   	export = function(s)
  -- 	  	-- local ss = get_sections(s)

  --   		-- return {find_section_index(s.selected_sequence_index),
  --   	end,

  --   	finish = function(s, m, o)
  --   		local ls = get_sections(renoise.song())
  --   		local sec = ls[m.selected]
  --   		s.transport.loop_sequence_range = {
  --         sec, section_end(s, sec)
  --       }
  --       if s.transport.playing and prefs.schedule_loops_when_playing.value then
  --         s.transport:set_scheduled_sequence(sec)
  --       else
  --         s.transport:start_at(renoise.SongPos(sec, 1))
  --       end
  --   	end,
  --   	-- init = function(s)
  --   	-- 	return find_section_index(s.selected_sequence_index)
  --   	-- end,
  --   	get_list = function(command)
  --     	local list = get_sections(renoise.song())
  --   	  return table:map(list,
  --   	    function(section, i)

  --   	    	return number_command(section.index.."", section.name, command.target, function(s,n)
  --     														show_frame("matrix")
  --   	    	                      return section.index end)
  --   	  end)
  -- 	  end
  --   }
  -- ),
  -- number_finder_command(
  --   "qs",
  --   "loop section",
  --   "transport.loop_sequence_range",
  --   function(s, n)
  --     local ss = get_sections(s)

  --     local i = s.selected_sequence_index
  --     local ni = clamp(i + n + -1 * sign(n), 1, s.transport.song_length.sequence)
  --     local loop_start = math.min(i, ni)
  --     local loop_end = math.max(i, ni)
  --     if s.transport.playing and prefs.schedule_loops_when_playing.value then
  --       s.transport:set_scheduled_sequence(loop_start)
  --     else
  --       s.transport:start_at(renoise.SongPos(loop_start, 1))
  --     end

  --     return { loop_start, loop_end }
  --     -- return clamp_in_list(n, ss)
  --   end,
  --   {
  --   	finish = function(s, callback)
  --       local fun = function(result, model)
  --         if result == CommandResult.quit then
  --         else
  --           s.transport.loop_sequence_range = {
  --             model.argument, section_end(s, model.argument)
  --           }
  --           if s.transport.playing and prefs.schedule_loops_when_playing.value then
  --             s.transport:set_scheduled_sequence(model.argument)
  --           else
  --             s.transport:start_at(renoise.SongPos(model.argument, 1))
  --           end
  --         end
  --         callback(result, model)
  --       end
  --       open_finder_palette("section", fun)
  --       show_frame("matrix")
  --     end
  --   }
  -- ),

  number_command("meb", "set metronome beats per bar", "transport.metronome_beats_per_bar", function(s, n)
    return clamp(n, 1, 16)
  end),

  toggle_command("tf", "toggle follow player", "transport.follow_player"),
  toggle_command("pw", "toggle pattern wrapping", "transport.wrapped_pattern_edit"),
  toggle_command("ste", "toggle single track edit", "transport.single_track_edit_mode"),
  toggle_command("met", "toggle metronome", "transport.metronome_enabled"),

  action_command("rsl", "remove slices", function(s, n)
    local sample = s.selected_sample
    if #sample.slice_markers > 0 then
      while #sample.slice_markers > 0 do
        sample:delete_slice_marker(sample.slice_markers[1])
      end
    end
  end),

  toggle_command("gro", "toggle groove", "transport.groove_enabled"),

  action_command("tt", "select track in pattern", function(s, n)
    if n == nil then
      s.selection_in_pattern = {
        start_line = 1,
        start_track = s.selected_track_index,
        end_line = s.selected_pattern.number_of_lines,
        end_track = s.selected_track_index,
      }
    elseif #s.tracks >= n then
      s.selection_in_pattern =
        { start_line = 1, start_track = n, end_line = s.selected_pattern.number_of_lines, end_track = n }
    end
  end),

  number_command("ta", "track alias in pattern", "selected_pattern_track.alias_pattern_index", function(s, n)
    if n == nil then
      return 0
    else
      if n + 1 == s.sequencer.pattern_sequence[s.selected_sequence_index] then
        return 0
      else
        return clamp(n + 1, 0, #s.patterns)
      end
    end
  end),

  action_command("tca", "clear track alias in pattern", function(s, n)
    s.selected_pattern_track.alias_pattern_index = 0
  end),

  action_command("cse", "clear section name", function(s, n)
    local index = find_section_index(s.selected_sequence_index)
    if index > 0 then
      s.sequencer:set_sequence_is_start_of_section(index, false)
    end
  end),

  string_input_command("ni", "rename instrument", "selected_instrument.name"),
  string_input_command("nsa", "rename sample", "selected_sample.name"),
  string_input_command("nt", "rename track", "selected_track.name"),
  string_input_command("np", "rename pattern", "selected_pattern.name"),
  string_input_command("nf", "rename phrase", "selected_phrase.name"),
  string_input_command("ne", "rename effect chain", "selected_sample_device_chain.name"),
  string_input_command("nm", "rename modulation set", "selected_sample_modulation_set.name"),

  action_command("nse", "rename section", function(s, n)
    local sq = s.sequencer
    local i = find_section_index(s.selected_sequence_index)
    if i > 0 then
      text_prompt("name section", function(t)
        local index = find_section_index(i)
        sq:set_sequence_section_name(i, t)
      end, sq:sequence_section_name(i))
    end
  end),

  toggle_column("tvc", "volume"),
  toggle_column("tdc", "delay"),
  toggle_column("tpc", "panning"),

  middle_show_action("ed", "show pattern editor", renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR),
  middle_show_action("mix", "show mixer", renoise.ApplicationWindow.MIDDLE_FRAME_MIXER),
  middle_show_action("ph", "show phrase", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PHRASE_EDITOR),
  middle_show_action("key", "show keyzones", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_KEYZONES),
  middle_show_action("sam", "show sample instrument", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EDITOR),
  middle_show_action("mod", "show modulation", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_MODULATION),
  middle_show_action("eff", "show sample effects", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_SAMPLE_EFFECTS),
  middle_show_action("plu", "show plugin", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_PLUGIN_EDITOR),
  middle_show_action("midi", "show midi", renoise.ApplicationWindow.MIDDLE_FRAME_INSTRUMENT_MIDI_EDITOR),

  action_command("ex", "show external plugin editor", function(s, n)
    local p = s.selected_instrument.plugin_properties
    local d = p.plugin_device
    if d ~= nil then
      if d.external_editor_available then
        d.external_editor_visible = not d.external_editor_visible
      end
    end
  end),

  action_command("hex", "hide all external editors", function(s, n)
    local hide_if_external = function(d)
      if d ~= nil then
        if d.external_editor_available then
          d.external_editor_visible = false
        end
      end
    end

    for i = 1, #s.instruments do
      hide_if_external(s:instrument(i).plugin_properties.plugin_device)
    end

    -- for i = 1, #s.instruments do
    -- 	for si = 1, #s:instrument(i).sample_modulation_sets do
    --   	for di = 1, #s:instrument(i):sample_modulation_set(si).devices do
    --   		if s:instrument(i):sample_modulation_set(si).devices[di].external_editor_visible then
    -- 	    	s:instrument(i):sample_modulation_set(si).devices[di].external_editor_visible = false
    -- 	    end
    --     end
    --   end
    -- end

    for i = 1, #s.tracks do
      for di = 1, #s:track(i).devices do
        hide_if_external(s:track(i).devices[di])
      end
    end
  end),

  action_command("ss", "show spectrum", function(_, _)
    local w = renoise.app().window
    if w.active_upper_frame ~= renoise.ApplicationWindow.UPPER_FRAME_MASTER_SPECTRUM then
      w.upper_frame_is_visible = true
    else
      w.upper_frame_is_visible = not w.upper_frame_is_visible
    end
    w.active_upper_frame = renoise.ApplicationWindow.UPPER_FRAME_MASTER_SPECTRUM
  end),

  action_command("sc", "show scopes", function(_, _)
    local w = renoise.app().window
    if w.active_upper_frame ~= renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES then
      w.upper_frame_is_visible = true
    else
      w.upper_frame_is_visible = not w.upper_frame_is_visible
    end
    w.active_upper_frame = renoise.ApplicationWindow.UPPER_FRAME_TRACK_SCOPES
  end),

  action_command("auto", "show automation", function(_, _)
    local w = renoise.app().window
    if
      not (
        w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        or w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
      )
    then
      w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
    end

    if w.active_lower_frame ~= renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION then
      w.lower_frame_is_visible = true
      w.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_AUTOMATION
    else
      w.lower_frame_is_visible = not w.lower_frame_is_visible
    end
  end),

  action_command("dsp", "show track DSP", function(_, _)
    local w = renoise.app().window
    if
      not (
        w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_PATTERN_EDITOR
        or w.active_middle_frame == renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
      )
    then
      w.active_middle_frame = renoise.ApplicationWindow.MIDDLE_FRAME_MIXER
    end

    if w.active_lower_frame ~= renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS then
      w.lower_frame_is_visible = true
      w.active_lower_frame = renoise.ApplicationWindow.LOWER_FRAME_TRACK_DSPS
    else
      w.lower_frame_is_visible = not w.lower_frame_is_visible
    end

  end),

  action_command("mat", "toggle matrix", function(s, n)
    show_frame("pattern")
    local w = renoise.app().window
    w.pattern_matrix_is_visible = not w.pattern_matrix_is_visible
  end),

  action_command("disk", "toggle disk browser", function(s, n)
    local w = renoise.app().window
    w.disk_browser_is_visible = not w.disk_browser_is_visible
  end),

  action_command("hide", "hide all", function(s, n)
    local w = renoise.app().window
    w.upper_frame_is_visible = false
    w.lower_frame_is_visible = false
    w.disk_browser_is_visible = false
    w.pattern_matrix_is_visible = false
  end),

  action_command("hu", "hide top (scopes, spectrum)", function(s, n)
    renoise.app().window.upper_frame_is_visible = false
  end),

  action_command("hl", "hide bottom (dsp, automation)", function(s, n)
    renoise.app().window.lower_frame_is_visible = false
  end),

  number_command("fl", "set phrase length", "selected_phrase.number_of_lines", function(s, n)
    return clamp(n, 1, 512)
  end),

  action_command("de", "deselect", function(s, n)
    s.selection_in_pattern = nil
    if s.selected_phrase ~= nil then
      s.selection_in_phrase = nil
    end
  end),

  -- CREATE NEW

  action_command("at", "add track(s)", function(s, n)
    n = n or 1
    for i = 1, n do
      local g = s:insert_track_at(s.selected_track_index + 1)
    end
    s.selected_track_index = s.selected_track_index + 1
  end),

  action_command("ag", "add group", function(s, n)
    if n == nil then
      local g = s:insert_group_at(s.selected_track_index + 1)
      s:add_track_to_group(s.selected_track_index, s.selected_track_index + 1)
    elseif #s.tracks >= n then
      local i = clamp(n, 1, #s.tracks)
      local g = s:insert_group_at(i)
    end
  end),

  action_command("cp", "clone pattern", function(s, n)
    local p = s.sequencer:insert_new_pattern_at(s.selected_sequence_index + 1)
    s.patterns[p]:copy_from(s.selected_pattern)
    local l = s.selected_pattern.number_of_lines
    s.sequencer:sort()
    s.selected_sequence_index = s.selected_sequence_index + 1
    if n ~= nil then
      s.selected_pattern.number_of_lines = clamp(s.transport.lpb * n, 1, 512 - (512 % s.transport.lpb))
    else
      s.selected_pattern.number_of_lines = l
    end
    for t = 1, #s.tracks do
      s.sequencer:set_track_sequence_slot_is_muted(
        t,
        s.selected_sequence_index,
        s.sequencer:track_sequence_slot_is_muted(t, s.selected_sequence_index - 1)
      )
    end
  end),

  action_command("ap", "add pattern (beats)", function(s, n)
    local p = s.sequencer:insert_new_pattern_at(s.selected_sequence_index + 1)
    s.selected_sequence_index = s.selected_sequence_index + 1
    if n ~= nil then
      s.selected_pattern.number_of_lines = clamp(s.transport.lpb * n, 1, 512 - (512 % s.transport.lpb))
    end
    s.sequencer:sort()
    show_frame("pattern")
  end),

  action_command("af", "add phrase (beats)", function(s, n, m)
    local i = s.selected_phrase_index + 1
    -- if i == 0 then return end
    local p = s.selected_instrument:insert_phrase_at(i)
    s.selected_phrase_index = i
    n = n and n or m.argument
    if n ~= nil then
      s.selected_phrase.number_of_lines = clamp(s.transport.lpb * n, 1, 512 - (512 % s.transport.lpb))
    end
    show_frame("phrase")
  end),

  action_command("ac", "add sample FX chain", function(s, n)
    local i = s.selected_sample_device_index
    s.selected_instrument:insert_sample_device_chain_at(i + 1)
    s.selected_sample_device_index = i + 1
    show_frame("effects")
  end),

  action_command("am", "add modulation set", function(s, n)
    local i = s.selected_sample_modulation_set_index
    s.selected_instrument:insert_sample_modulation_set_at(i + 1)
    s.selected_sample_modulation_set_index = i + 1
    show_frame("modulation")
  end),

  action_command("ase", "add section", function(s, n)
    text_prompt("name section", function(t)
      local sq = s.sequencer
      local index = s.selected_sequence_index
      if sq:sequence_is_start_of_section(index) then
        sq:set_sequence_section_name(index, t)
      else
        sq:set_sequence_is_start_of_section(index, true)
        sq:set_sequence_section_name(index, t)
      end
    end, "")
  end),

  action_command("asa", "add sample", function(s, n)
    show_frame("sample")
    local i = s.selected_sample_index + 1
    s.selected_instrument:insert_sample_at(i)
    s.selected_sample_index = i
  end),

  action_command("rsa", "remove sample", function(s, n)
    show_frame("sample")
    s.selected_instrument:delete_sample_at(s.selected_sample_index)
  end),

  action_command("rs", "remove sequence step", function(s, n)
    n = n and clamp(n, 1, #s.sequencer.pattern_sequence) or s.selected_sequence_index
    if #s.sequencer.pattern_sequence > 1 then
      s.sequencer:delete_sequence_at(n)
    end
  end),

  action_command("rt", "remove track", function(s, n)
    n = n or s.selected_track_index
    if s.tracks[n].type ~= renoise.Track.TRACK_TYPE_MASTER then
      if not (n == 1 and s.tracks[n + 1].type == renoise.Track.TRACK_TYPE_MASTER) then
        s.selected_track_index = s.selected_track_index + 1
        s:delete_track_at(n)
        return "deleted track at " .. n
      end
    end
    return "this track cannot be deleted"
  end),

  -- MIXING
  action_command("st", "solo track", function(s, n)
    if n == nil then
      s.selected_track:solo()
    elseif #s.tracks >= n then
      s.tracks[n]:solo()
    end
  end),

  action_command("mt", "mute track", function(s, n)
    if n == nil then
      if s.selected_track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
        s.selected_track:mute()
      else
        s.selected_track:unmute()
      end
    elseif #s.tracks >= n then
      if s.selected_track.mute_state == renoise.Track.MUTE_STATE_ACTIVE then
        s.tracks[n]:mute()
      else
        s.tracks[n]:unmute()
      end
    end
  end),

  number_command("l", "set pattern length by beats", "selected_pattern.number_of_lines", function(s, n)
    return clamp(s.transport.lpb * n, 1, 512 - (512 % s.transport.lpb))
  end),

  number_command("ll", "set pattern length by lines", "selected_pattern.number_of_lines", function(s, n)
    return clamp(n, 1, 512)
  end),

  number_command("N", "set number of Note columns", "selected_track.visible_note_columns", function(s, n)
    if s.selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      return clamp(n, 1, 12)
    else
      return 0
    end
  end),

  number_command("F", "set number of FX columns", "selected_track.visible_effect_columns", function(s, n)
    if s.selected_track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      return clamp(n, 0, 8)
    else
      return clamp(n, 1, 8)
    end
  end),

  -- number_command(
  --   "loopr",
  --   "set sample looping",
  --   "selected_sample.loop_mode",
  --   function(s, n) return renoise.SampleEnvelopeModulationDevice.LOOP_MODE_REVERSE end
  -- ),
  -- number_command(
  --   "loopf",
  --   "loop forward",
  --   "selected_sample.loop_mode",
  --   function(s, n) return renoise.SampleEnvelopeModulationDevice.LOOP_MODE_FORWARD end
  -- ),
  -- number_command(
  --   "loopp",
  --   "loop ping pong",
  --   "selected_sample.loop_mode",
  --   function(s, n) return renoise.SampleEnvelopeModulationDevice.LOOP_MODE_PING_PONG end
  -- ),

  new_command(
    CommandType.number,
    "mv", "set master volume",
    function(s)
      return s.tracks[s.sequencer_track_count + 1].postfx_volume.value
    end,
    function(s, n)
      if n ~= nil then
        s.tracks[s.sequencer_track_count + 1].postfx_volume.value = math.db2lin(clamp(n,-46, 3))
      end
    end,
    function(s) 
    end,
    function(s, initial)
      s.tracks[s.sequencer_track_count + 1].postfx_volume.value = initial
    end
  ),

  toggle_command("im", "toggle instrument monophony", "selected_instrument.trigger_options.monophonic"),

  number_command(
    "it", "set instrument transpose", "selected_instrument.transpose", 
    function(s, n)
      return clamp(n, -120, 120)
    end
  ),

  number_command(
    "iv", "set instrument volume", "selected_instrument.volume", 
    function(s, n)
      return math.db2lin(clamp(n, -96, 6))
    end
  ),

  -- DEVICES

  action_command("ad", "add DSP device", function(s, n)
    if sampler_visible() then
      open_device_palette("sample")
    else
      open_device_palette("track")
    end
  end),

  action_command("rd", "remove selected DSP device", function(s, n)
    if sampler_visible() then
      if s.selected_sample_device_chain then
        if s.selected_sample_device then
          local di = s.selected_sample_device_index
          if di > 1 then
            s.selected_sample_device_chain:delete_device_at(di)
            s.selected_sample_device_index = clamp(di - 1, 1, #s.selected_sample_device_chain.devices)
          else
            log("can't remove vol/pan device")
          end
        end
      end
    else
      local di = s.selected_track_device_index
      if di > 1 then
        s.selected_track:delete_device_at(di)
        s.selected_track_device_index = clamp(di - 1, 1, #s.selected_track.devices)
      else
        log("can't remove vol/pan device")
      end
    end
  end),

  action_finder_command("msf", "set filter type for modulation", {
    -- run = function (a,b,c)
    -- end,
    get_list = function (c)
      local s = renoise.song()
      local list = table:map(s.selected_sample_modulation_set.available_filter_types, function(ft, i)
        return action_command(i.."", ft, function() s.selected_sample_modulation_set.filter_type = ft end)
      end)
      return list
    end
  }),

  action_finder_command("pr", "pick device preset", {
    finish = function(s, n)
      if tracks_visible() then
        pick_preset(s.selected_track_device).finish(s, n)
      else
        if s.selected_sample_device then
          pick_preset(s.selected_sample_device).finish(s, n)
        end
      end
    end,
  }),
  -- action_command(
  --   "ade",
  --   "add effect to sample",
  --   function(s, n) open_device_palette("sample", 1) end
  -- ),
  -- number_finder_command(
  --   "pres",
  --   "preset for sample effect device",
  --   "selected_sample_device.active_preset",
  --   function(s, n)
  --   	return clamp(n + 1, 1, #s.selected_sample_device.presets)
  --   end,

  --   {
  --   	export = function(s)
  --   		if s.selected_sample_device then
  -- 	  		return s.selected_sample_device.active_preset
  -- 	  	end
  --   	end,
  --   	get_list = function(command)
  --   		local song = renoise.song()
  -- 	  	local list = table:map(song.selected_sample_device.presets, function(instrument, i)

  -- 	  	  return number_command(i.."", song.selected_sample_device.presets[i], command.target, function(s,n) return i end) end)
  -- 	  	return list
  -- 	  end,
  --   }
  -- ),
  action_command("avol", "add volume modulation", function(s, n)
    open_device_palette("modulation", DeviceSubType.volume)
  end),

  action_command("apan", "add panning modulation", function(s, n)
    open_device_palette("modulation", DeviceSubType.panning)
  end),
  
  action_command("api", "add pitch modulation", function(s, n)
    open_device_palette("modulation", DeviceSubType.pitch)
  end),
}

-- new_string_action_command(
--   "se",
--   "go to section",
--   "selected_sequence_index",
--   function(s, n)

--     -- s.sequencer:set_track_sequence_slot_is_selected(s.selected_track_index, i, true)
--     -- s.sequencer:set_track_sequence_slot_is_selected(s.selected_track_index, s.selected_sequence_index, false)

--     local i = clamp(n + 1, 1, s.transport.song_length.sequence)
--     -- if s.transport.playing then
--     --   s.transport:set_scheduled_sequence(i)
--     -- end
--     return i
--   end
-- ),
-- new_number_value_command(
--   "s",
--   "go to step in sequence",
--   "selected_sequence_index",
--   function(s, n)

--     -- s.sequencer:set_track_sequence_slot_is_selected(s.selected_track_index, i, true)
--     -- s.sequencer:set_track_sequence_slot_is_selected(s.selected_track_index, s.selected_sequence_index, false)

--     local i = clamp(n + 1, 1, s.transport.song_length.sequence)
--     -- if s.transport.playing then
--     --   s.transport:set_scheduled_sequence(i)
--     -- end
--     return i
--   end
-- ),
-- new_number_value_command(
--   "v",
--   "set volume",
--   "",
--   function(s, n)
--     for t = 1, #s.tracks do
--       if s.tracks[t].type == renoise.Track.TRACK_TYPE_MASTER then
--         local v = s.tracks[t].postfx_volume
--         v.value = clamp(v.value_min + (v.value_max - v.value_min) * (n / 100), v.value_min, v.value_max)
--         return v.value
--       end
--     end
--   end,
--   function(s)
--     for t = 1, #s.tracks do
--       if s.tracks[t].type == renoise.Track.TRACK_TYPE_MASTER then
--         local v = s.tracks[t].postfx_volume
--         return v.value
--       end
--     end
--   end,
--   function(s, val)
--     for t = 1, #s.tracks do
--       if s.tracks[t].type == renoise.Track.TRACK_TYPE_MASTER then
--         local v = s.tracks[t].postfx_volume
--         v.value = clamp(v.value_min + (v.value_max - v.value_min) * (val / 100), v.value_min, v.value_max)
--         -- return v.value
--       end
--     end
--   end,
--   function(song, v)
--     return math.floor(v * 100)
--   end
-- ),

-- new_number_value_command(
--   "p",
--   "set pattern",
--   "selected_pattern_index",
--   function(s, n)
--     return clamp(n + 1, 1, 1000)
--   end
-- ),

-- new_action(
--   "u",
--   "loop selection in matrix",
--   function(s)
--     local selection = selection_in_matrix()
--     if s.transport.playing then
--       s.transport:set_scheduled_sequence(selection.start_line)
--     end
--     s.transport.loop_sequence_range = { selection.start_line, selection.end_line }
--   end
-- ),
