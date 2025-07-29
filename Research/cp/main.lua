require("util")
require("constants")
require("lui")
require("commands")

name = "command palette"

-- window = nil

-- View = nil

---@class Prefs : renoise.Document.DocumentNode
---@field wrapping renoise.Document.ObservableBoolean
---@field use_mono_font renoise.Document.ObservableBoolean
---@field spacing renoise.Document.ObservableNumber
---@field width renoise.Document.ObservableNumber
---@field max_results renoise.Document.ObservableNumber
---@field ninja_mode renoise.Document.ObservableBoolean
---@field schedule_loops_when_playing renoise.Document.ObservableBoolean
---@field parameter_step_division renoise.Document.ObservableNumber
---@field text_format renoise.Document.ObservableNumber
---@field show_tips renoise.Document.ObservableBoolean
---@field binds renoise.Document.ObservableString
---@field escape_deletes renoise.Document.ObservableBoolean


---@type Prefs
prefs = renoise.Document.create("ScriptingToolPreferences")(default_prefs())

tool = renoise.tool()

tool.preferences = prefs

---@class HistoryFrame
---@field alias string
---@field argument integer?

---@class Model
---@field title string
---@field list any[]
---@field initial_target_value any
---@field constant_list any[]
---@field selected integer
---@field base_command Command?
---@field argument integer?
---@field history HistoryFrame[]
---@field width number
---@field initial any
---@field sign integer
---@field scroll integer
---@field history_pos integer
---@field text_input string
---@field untouched boolean
---@field get_list fun(c: Command):any[]

---@type Model
Model = {
  title = "",
  get_list = function() return {} end,
  list = {},
  constant_list = {},
  selected = 0,
  untouched = true,
  history = {},
  history_pos = 0,
  text_input = "",
  sign = 1,
  scroll = 0,
  argument = nil,
  width = prefs.width.value,
  initial = nil,
}

---@class State
---@field title string
---@field init function
---@field model Model
---@field update function
---@field view fun(m:Model):renoise.Views.Rack
---@field keypress fun(e:KeyEvent, m: Model?, s: State?):Message
---@field callback (fun(r, m: Model, o: State))?


---@type HistoryFrame[]
History = {}

SettingsDialog = nil

---@type fun(alias:string, argument:integer?)
function remember(alias, argument)
  if #History == 0 or (History[1].alias ~= alias and History[1].argument ~= argument) then
    table.insert(History, 1, command_call(alias, argument))
  end
end

_vb = renoise.ViewBuilder()

---@type fun():string
function text_font()
  if prefs.use_mono_font.value then
    return "mono"
  else
    return "normal"
  end
end

---@type fun(text:string, style:TextStyle):renoise.Views.Text
function styled_text(text, style)
  return _vb:text({
    style = style,
    font = text_font(),
    text = text_transform(text),
  })
end

---@type fun(text:string, style:TextStyle?):renoise.Views.Text
function raw_text(string, style)
  return _vb:text({
    style = style,
    font = text_font(),
    text = string,
  })
end

---@alias TextBuilder fun(text:string):renoise.Views.View

---@type TextBuilder
function normal_text(string)
  return styled_text(string, "normal")
end

---@type TextBuilder
function soft_text(string)
  return styled_text(string, "disabled")
end

---@type TextBuilder
function strong_text(string)
  return styled_text(string, "strong")
end

---@type fun(command:Command):string
function command_as_string(c)
  return search_query(c.name)..c.alias..(c.bind and c.bind or "")
end

---@type fun(command:Command, input:string):integer
function match_score(command, input)
  local n = string.lower(command.name)
  local i = string.lower(input)

  local score = 0
  if command.alias == input.sub(1, #command.alias) then
    return 100
  end

  if command.alias:find(i) then
    score = score + 50
  end
  if n:find(i) then
    score = score + 1
  end

  return score
end

---@type fun(list:Command[], input:string):Command[]
function sort_matches(list, input)
  table.sort(list, function(a, b)
    return match_score(b, input) > match_score(a, input)
  end)
  return list
end

---@type fun(t:string):string
function text_transform(t)
  local ts = prefs.text_format.value
  if ts == TextFormat.capitalized then
    return capitalize_all(t)
  elseif ts == TextFormat.lowercase then
    return string.lower(t)
  elseif ts == TextFormat.uppercase then
    return string.upper(t)
  else
    return t
  end
end

---@type fun(e:KeyEvent):string?
function to_letter(e)
  local l = ifelse(e.name == "space", " ", e.character)
  if tonumber(e.name, 10) == nil and (l ~= nil and #l == 1 and l ~= "`") then
    return l
  else
    return nil
  end
end

---@type fun(list:Command[], alias:string):Command?
function command_by_alias(list, alias)
  return table:find_by(list, function(c)
    return (c.bind and (c.bind == alias)) or c.alias == alias
  end)
end

---@type fun(m:Model)
function select_alias(m)
  -- rprint(m.list)
  local c = command_by_alias(m.list, m.text_input)
  if c ~= nil then
    local i = table:find_index(m.list, function(_c)
      return _c.alias == c.alias or _c.bind == c.alias
    end)
    if i ~= 0 then
      local scroll_delta = m.scroll - m.selected
      m.selected = i
      m.scroll = clamp(m.selected + scroll_delta - 1, 0, math.max(#m.list - prefs.max_results.value, 0))
      m.initial = c.init(renoise.song())
    end
  end
  -- rprint(c)
end

---@type fun(m:Model):Model
function init(m)
  local song = renoise.song()

  m.argument = nil
  m.untouched = true
  m.history_pos = 0

  if #History > 0 then
    local c = command_by_alias(m.list, History[1].alias)
    m.text_input = History[1].alias
    m.argument = nil
    m.sign = 1
    select_alias(m)
  end
  return m
end

---@type fun(m:Model):integer?
function argument(m)
	if m.argument == nil then return nil
	else return m.argument * m.sign
	end
end

---@alias Msg
---| "init"
---| "bind"
---| "negate"
---| "text"
---| "argument"
---| "delete"
---| "move"
---| "quit"
---| "finish"
---| "crawl_history"

---@alias Message {type :Msg, value:any}

---@type fun(m:Model, msg:Message, o):CommandResult
function update(m, msg, o)
  local touchfirst = function()
    if m.untouched then
      m.sign = 1
      m.list = table:map(m.constant_list, function(c, i)
        return c
      end)
      m.untouched = false
      m.text_input = ""
      m.argument = nil
      m.history_pos = 0
      return true
    else
      return false
    end
  end
  local song = renoise.song()

  if msg == nil then
  elseif msg.type == "bind" then
    -- if m.selected > 0 then
    -- local a = m.list[m.selected].alias

    -- local c = table:find_by(commands, function(x) return x.alias == a end)

    -- if a == msg.value then
    -- 	c.bind = nil
    -- else
    -- 	prefs.binds.value = prefs.binds.value .. "," .. a .. "=" .. msg.value
    -- 	c.bind = msg.value
    -- end
    -- restore_target(renoise.song(), m.list[m.selected], m.initial_target_value)
    -- renoise.app():show_status("'"..a.."' is now '" .. msg.value .. "'")
    -- return 0
    -- end
  elseif msg.type == "negate" then
    m.sign = -1
    local result = m.list[m.selected].run(song, argument(m), m.initial)
  elseif msg.type == "text" then
    touchfirst()

    -- user input a letter, init command if there is a match
    m.text_input = extend_text(m.text_input, msg.value)
    select_alias(m)
  elseif msg.type == "argument" then
    local sign = m.text_input[#m.text_input] == "-" and -1 or 1
    -- user input a number, set the argument and apply command
    if m.argument ~= nil then
      m.argument = tonumber((m.argument .. "") .. msg.value, 10)
    else
      m.argument = tonumber(msg.value, 10)
    end

    local result = m.list[m.selected].run(song, argument(m), m.initial)
  elseif msg.type == "delete" then
    local command = m.list[m.selected]
    -- print("delete ", m.argument)
    -- touchfirst()
    -- user deleted a character
    if m.argument ~= nil then
      -- if there is an argument delete it and apply if there is something left
      if #(m.argument .. "") > 1 then
        m.argument = tonumber((m.argument .. ""):sub(1, #(m.argument .. "") - 1), 10)
        local result = command.run(renoise.song(), argument(m), m.initial)
      else
        m.argument = nil
        m.sign = 1
        command.cancel(song, m.initial)
        -- restore_target(renoise.song(), m.list[m.selected], m.initial_target_value)
      end
    else
      -- if there's only text, delete it
      m.text_input = m.text_input:sub(1, #m.text_input - 1)
      -- restore_target(renoise.song(), m.list[m.selected], m.initial_target_value)
    end
  elseif msg.type == "move" then
    -- move the selection in the list, init command

    if msg.value.mod then
      if tonumber(m.initial) ~= nil then
        if m.argument == nil then
          m.argument = m.initial
        end
        m.argument = m.argument + msg.value.direction
        local result = m.list[m.selected].run(song, argument(m), m.initial)
        return CommandResult.continue
      end
    else
      m.argument = nil
      local stepped =
        step_selected(msg.value.direction, m.selected, m.scroll, m.list, prefs.wrapping.value, prefs.max_results.value)

      m.selected = stepped.selected
      m.scroll = stepped.scroll

      m.initial = m.list[m.selected].init(song)
      return CommandResult.continue
    end
  elseif msg.type == "quit" then
    if prefs.escape_deletes.value and m.text_input ~= "" then
      touchfirst()
      m.text_input = ""
      select_alias(m)
    else
      -- revert changes from argument input
      local command = m.list[m.selected]
      command.cancel(song, m.initial)
      return CommandResult.quit
    end
  elseif msg.type == "finish" then
    --  set callback to execute command after dialog is closed
    o.callback = function(result, m, o)
      local command = m.list[m.selected]
      local result = command.run(song, argument(m), m.initial)
      if m.argument ~= nil then
        command.finish(renoise.song(), argument(m), m)
        table.insert(m.history, 1, command_call(command.alias, argument(m)))
      else
        if command.type == CommandType.action or command.type == CommandType.string then
          command.finish(renoise.song(), nil, m)
          remember(command.alias, nil)
        end
      end
    end
    return CommandResult.success
  elseif msg.type == "crawl_history" then
    -- print(msg.value)
    local p = clamp(m.history_pos + msg.value, 0, #m.history)
    if m.history_pos ~= p then
      m.history_pos = p
      if m.history_pos > 0 then
        m.text_input = m.history[m.history_pos].alias
        m.argument = m.history[m.history_pos].argument
        m.list = table:map(commands, function(c)
          return c
        end)
        select_alias(m)
        return CommandResult.continue
      else
        m.text_input = ""
        m.argument = nil
      end

      -- if m.argument ~= nil then
      local result = m.list[m.selected].run(renoise.song(), argument(m), m.initial)
      -- end
    end
  end

  -- store the command alias before filtering the list
  local name_before = ""
  if m.selected > 0 then
    name_before = m.list[m.selected].name
  end

  -- filter commands based on input
  local ls = ranked_matches(m.constant_list, m.text_input, command_as_string)

  if #ls > 0 then
    m.list = ls

    -- restore the previous alias if it's still in the list
    local index = table:find_index(m.list, function(c)
      return c.name == name_before
    end)

    if index == 0 then
      index = 1
    end

    m.scroll = step_scroll(m.selected, index, m.scroll, #m.list)
    m.selected = index
    local command = m.list[index]
    -- initialize the selected command if it changed
    if command.name ~= name_before then
      m.initial = m.list[m.selected].init(song)
    end
  end

  return CommandResult.continue
end

---@type fun(t:Msg, v:any):Message
function message(t, v)
  return { type = t, value = v }
end

---@type fun(command:Command):renoise.Views.View
function command_view(command)
  local vb = renoise.ViewBuilder()
  local alias = command.bind and command.bind or command.alias
  -- local separator = command.bind and " = " or " : "
  return {
    raw_text(alias, "disabled"),
    strong_text(command.name),
  }
end

---@type fun(m:Model):renoise.Views.Rack
function view(m)
  local vb = renoise.ViewBuilder()
  local command = m.selected > 0 and m.list[m.selected] or nil
  local alias = command and m.list[m.selected].alias or ""
  local arg = ""
  local initial = (m.initial_target_value and m.initial_target_value or "")
  if type(initial) == "table" then
    initial = "{}"
  end
  if command ~= nil and m.argument == nil and m.sign == 1 then
    arg = match(command.type, {
      [CommandType.number] = "#",
      [CommandType.string] = "=",
      [CommandType.action] = ">",
      [CommandType.custom] = "#",
      _ = "",
    })
  else
    arg = m.argument ~= nil and (argument(m)) .. "" or (m.sign > 0 and "" or "-")
  end
  return vb:column({
    width = "100%",
    vb:row({
      vb:button({
        text = command.bind and command.bind or alias,
      }),
      raw_text(m.text_input),
      vb:text({
        font = text_font(),
        align = "right",
        style = "disabled",
        text = ifelse(prefs.ninja_mode.value, "", command and text_transform(m.list[m.selected].name) .. " " or ""),
      }),
      normal_text(arg .. " "),
    }),
    ifelse(prefs.ninja_mode.value, nil, list_view(m.list, command_view, m.selected, m.scroll)),
  })
end

---@type fun(model:Model, history:HistoryFrame[]):State
function create_pal(model, history)
  model = {
    get_list = model.get_list,
    base_command = model.base_command,
    list = model.get_list(model.base_command),
    constant_list = model.get_list(model.base_command),

    title = model.title and ifelse(prefs.ninja_mode.value, "", model.title) or "",
    selected = 0,
    scroll = 0,
    untouched = true,
    history = history and history or {},
    history_pos = 0,
    text_input = "",
    sign = 1,
    argument = nil,
    width = prefs.width.value,
    initial = nil,
  }

  -- apply user binds
  -- local bs = string:split(prefs.binds.value, ",")
  -- for i = 1, #bs do
  -- 	local ab = string:split(bs[i], "=")
  -- 	local c = command_by_alias(ab[1])
  -- 	if c ~= nil then
  -- 		c.bind = ab[2]
  -- 	end
  -- end

  local palette = finder_list({
    title = model.title,
    init = init,
    model = model,
    update = update,
    view = view,
    keypress = function(e)
      local input_letter = to_letter(e)

      if e.modifiers == "alt" then
        if input_letter and input_letter ~= "-" then
          return message("bind", input_letter)
        end
      end

      local msg = input_letter and message("text", input_letter) or nil
      if input_letter == "-" then
        msg = message("negate")
      end

      if msg == nil then
        local input_number = tonumber(e.name, 10)
        if input_number == nil and e.name:sub(1, #"numpad numpad") == "numpad numpad" then
          input_number = tonumber(e.name:sub(#"numpad numpad" + 1))
        end
        msg = input_number and message("argument", input_number) or nil
      end

      local move_value = function (direction, mod)
        return { direction = direction, mod = mod }
      end

      if msg == nil then
        local is_alt = e.modifiers == "alt"
        msg = match(e.name, {
          down = message("move", move_value(1, is_alt)),
          ["`"] = message("move", move_value(-1, is_alt)),
          tab = message("move", move_value(ifelse(e.modifiers == "shift", -1, 1), is_alt)),
          up = message("move", move_value(-1, is_alt)),
          left = message("crawl_history", 1),
          right = message("crawl_history", -1),
          esc = message("quit"),
          back = message("delete"),
          ["return"] = message("finish"),
        })
      end
      return msg
    end,
  })
  return palette
end

---@type fun(opened:boolean)
function open_pal(reopened)
  local palette = create_pal({
    -- apply user binds
    -- local bs = string:split(prefs.binds.value, ",")
    -- for i = 1, #bs do
    -- 	local ab = string:split(bs[i], "=")
    -- 	local c = command_by_alias(ab[1])
    -- 	if c ~= nil then
    -- 		c.bind = ab[2]
    -- 	end
    -- end

    title = text_transform("command palette"),
    get_list = function()
      return commands
    end,
  }, History)
end

---@type fun():string
function help()
  local ls = {
    "Navigate and configure a song using the keyboard.",
    "",
    "Provides two key-bindings in *Global / Tools*",
    "",
    "- Open command palette",
    "- Repeat last command",
    "",
    "### usage",
    "",
    "- open the command palette",
    "- search for what you want by typing letters",
    "- change the selected command with up or down",
    "- type some number",
    "- press enter to apply and exit",
    "",
    "- delete your input with backspace",
    "- escape will cancel the command and close the popup",
    "- press left to recall previous commands",
    "",
    "### command types",
    "- number commands are the most common, they will show a # symbol in your top bar when you select them. These accept a single number that you can type in as soon as you have the command selected and it will be executed immeditately when the input is changed.",
    "",
    "- action commands either require no input or more complex input that can be set in a separate window. These won't do anything until you press enter. They have the sign >",
    "",
    "- string commands can for example rename things. These are noted with the = sign and they will open a separate text input window for you to provide the text string",
    "",
    "",
    "Some commands open secondary palettes, these work the same way: just type or navigate until you have the match then hit enter. Some number commands will let you excecute them without input and they will open a search palette for you to pick something by text instead of providing an index.",
    "",
    "For example if you run the 't' or 'select track' command without an input number it will list all the tracks by name and will let you search and navigate it similarly to the main palette. The same thing works for instruments, samples or sections and even DSP devices across the whole song. If you name your things right this can help you a lot in navigating using the keyboard.",
    "",
    "You can open the settings from the palette anytime by searching for 'settings' or with the '/s'.",
  }
  return string:join(ls, "\n")
end

---@type fun(vb:ViewBuilderInstance, key:string, text:string):renoise.Views.Rack
function toggle_row(vb, key, text)
  return vb:row({
    margin = 1,
    spacing = 1,
    vb:checkbox({
      bind = prefs[key],
    }),
    normal_text(text),
  })
end

---@type fun(vb:ViewBuilderInstance, key:string, text:string, min:number, max:number):renoise.Views.Rack
function integer_setting(vb, key, text, min, max)
  return vb:row({
    spacing = 5,
    vb:row({
      margin = 5,
      vb:valuebox({
        min = min,
        max = max,
        bind = prefs[key],
      }),
      normal_text(" " .. text_transform(text)),
    }),
  })
end

---@type fun(show_help:boolean)
function open_settings(show_help)
  local vb = renoise.ViewBuilder()
  local reopen = function(help)
    local h = ifelse(help == nil, show_help, help)
    if SettingsDialog then
      SettingsDialog:close()
      SettingsDialog = nil
    end
    open_settings(h)
  end
  local content = vb:column({
    width = 300,
    margin = 15,
    spacing = 5,
    integer_setting(vb, "max_results", "max results to show", 1, 42),
    integer_setting(vb, "width", "width of the window", 150, 500),
    integer_setting(vb, "spacing", "space between lines", 0, 20),
    vb:row({
      spacing = 5,
      width = "100%",
      vb:row({
        width = "100%",
        margin = 5,
        vb:switch({
          width = 250,

          items = {
            "lowercase",
            "Capitalized",
            "UPPERCASE",
          },
          bind = prefs.text_format,
          notifier = reopen,
        }),
      }),
    }),
    toggle_row(vb, "use_mono_font", "monospace font"),
    toggle_row(vb, "show_tips", "show tips"),
    toggle_row(vb, "ninja_mode", "hide everything"),
    toggle_row(vb, "wrapping", "wrap list at the edges"),
    toggle_row(vb, "schedule_loops_while_playing", "jump to loops if playing"),
    toggle_row(vb, "escape_deletes", "ESC to clear input"),
    -- vb:row{
    --   margin = 1,
    -- 	vb:text {
    --   	font = text_font(),
    --     text = text_transform("user bindings"),
    -- 	},
    -- 	vb:textfield {
    --     text = prefs.binds.value,
    --     bind = prefs.binds,
    --   },
    -- },

    vb:row({
      margin = 5,
      vb:horizontal_aligner({
        spacing = 5,
        mode = "justify",
        vb:button({
          text = text_transform("show help"),
          pressed = function()
            SettingsDialog:close()
            reopen(true)
          end,
        }),
        vb:button({
          text = text_transform("reset defaults"),
          pressed = function()
            SettingsDialog:close()
            local dp = default_prefs()
            for key, value in pairs(dp) do
              print(key, value)
              prefs[key].value = value
            end

            reopen()
          end,
        }),
        link_button(
          text_transform("source"),
          "https://gitlab.com/unlessgames/unless_renoise/-/tree/master/com.unlessgames.command_palette.xrnx"
        ),
        link_button(text_transform("play a game"), "https://unlessgames.itch.io"),
      }),
    }),
  })

  if show_help then
    content = vb:row({
      width = 600,
      height = 420,
      uniform = true,
      vb:column({
        margin = 20,
        width = 300,
        height = 420,
        style = "group",
        vb:multiline_text({
          width = 280,
          height = 380,
          font = text_font(),
          text = help(),
        }),
      }),
      content,
    })
  end

  SettingsDialog = renoise.app():show_custom_dialog(text_transform(name .. " - settings"), content)
end

-- GUI

tool:add_menu_entry({
  name = "Main Menu:Tools:" .. name,
  invoke = function()
    open_settings(true)
  end,
})

tool:add_keybinding({
  name = "Global:Tools:Open command palette",
  invoke = function()
    open_pal(false)
  end,
})


tool:add_midi_mapping({
  name = "Global:Tools:Open command palette",
  invoke = function()
    open_pal(false)
  end,
})


tool:add_keybinding({
  name = "Global:Tools:Repeat last command",
  invoke = function()
    if #History > 0 then
      local c = command_by_alias(commands, History[1].alias)
      if c then
        c.run(renoise.song(), History[1].argument)
        c.finish(renoise.song())
      end
    end
  end,
})


---@type fun(cs:Command[])
function validate_commands(cs)
  local command_names = {}
  for i = 1, #cs do
    cs[i].name = cs[i].name .. "  "
    if cs[i].alias ~= "" then
      if command_names[cs[i].alias] ~= nil then
        print("duplicate alias!!!", cs[i].alias, cs[i].name, " = ", command_names[cs[i].alias])
      end
      command_names[cs[i].alias] = cs[i].name
    end
  end
end

table.insert(
  commands,
  action_command("/s", "show palette settings", function(s, v)
    open_settings(false)
    return nil
  end, {
    finish = function(s, m, o)
    end,
  })
)

table.insert(
  commands,
  action_command("help", "show help", function(s, v)
    open_settings(true)
  end)
)

validate_commands(commands)

---@type fun(c:Command?)
function run_command_with_empty(c)
  if c then
    -- rprint(c)
    local s = renoise.song()
    if s then
      if c.type == CommandType.action then
        c.finish()
      elseif c.type == CommandType.number then
        c.empty(s, c.export(s))
      else

      end      
    end
  end
end

---@type fun(alias: string, name : string)
function add_argument_palette_binding(alias, name)
  local bind = {
    name = "Global:Tools:Open ".. name .." palette",
    invoke = function()
      run_command_with_empty(command_by_alias(commands, alias))
    end
  }
  tool:add_keybinding(bind)
  tool:add_midi_mapping(bind)
end

add_argument_palette_binding("i", "instrument")
add_argument_palette_binding("t", "track")
add_argument_palette_binding("pl", "plugin")
add_argument_palette_binding("s", "sequence")
add_argument_palette_binding("sa", "sample")
add_argument_palette_binding("f", "phrase")
add_argument_palette_binding("p", "pattern")
add_argument_palette_binding("ad", "add DSP")
add_argument_palette_binding("d", "DSP")

-- -- load command bindings from other tools ... not yet
-- local ts = renoise.app().installed_tools
-- _commands = nil

-- for key, t in pairs(ts) do
-- 	_commands = nil

-- 	include(t.id ..".xrnx", "_commands")

-- 	if _commands ~= nil then
-- 		local ls = _commands()
-- 		print(t.id, "has tool commands")
-- 		for i = 1, #ls do
-- 			rprint(ls[i])
-- 			table.insert(commands, new_action_command("", ls[i].name, ls[i].invoke))
-- 		end
-- 	end
-- end

_AUTO_RELOAD_DEBUG = function() end

print(name .. " loaded. ")
