require("constants")
require("argument_palette")

---@alias Init<T> fun(song : renoise.Song) : T
---@alias Run<T> fun(song : renoise.Song, arg : T, initial : T) : T
---@alias Finish<T> fun(song : renoise.Song, arg : T) : T
---@alias Cancel<T> fun(song : renoise.Song, initial : T) : T
---@alias Void fun() : nil
---@alias SongInitialToAny<T> fun(song: renoise.Song, initial: T) T


---@class Command
---@field type CommandType
---@field alias string
---@field name string
---@field bind any
---@field init Init | Void
---@field run Run | Void
---@field finish Finish | Void
---@field cancel Cancel | Void
---@field empty SongInitialToAny
---@field get_list fun() 
---@field export SongInitialToAny
---@field validate SongInitialToAny


---@type fun(type : CommandType, alias : string, name : string, init : Init?, run : Run?, finish : Finish?, cancel : Cancel?) : Command
function new_command(type, alias, name, init, run, finish, cancel)
  local void = function()
    return nil
  end
  return {
    type = type,
    alias = alias,
    name = name,
    bind = nil,
    init = init and init or void,
    run = run and run or void,
    finish = finish and finish or void,
    cancel = cancel and cancel or void,
  }
end

---@type fun(song : renoise.Song, target : string) : number | boolean | string | nil
function get_song_property(song, target)
  local t = string:split(target, ".")
  if #t == 1 then
    return song[t[1]]
  elseif #t == 2 and song[t[1]] ~= nil then
    return song[t[1]][t[2]]
  elseif #t == 3 and song[t[1]][t[2]] ~= nil then
    return song[t[1]][t[2]][t[3]]
  else
    return nil
  end
end

---@type fun(song : renoise.Song, target : string, value : any) : string?
function set_song_property(song, target, value)
  local t = string:split(target, ".")
  pcall(function()
    if song[t[1]] == nil then
      return "'" .. t[2] .. "' doesn't exist"
    else
      if #t == 1 then
        song[t[1]] = value
        return nil
      elseif #t == 2 and song[t[1]] ~= nil then
        song[t[1]][t[2]] = value
        return nil
      elseif #t == 3 and song[t[1]][t[2]] ~= nil then
        song[t[1]][t[2]][t[3]] = value
        return nil
      else
        return "'" .. t[2] .. "' doesn't exist in '" .. t[1] .. "'"
      end
    end
  end)
end

---@class CommandOptions
---@field validate (fun(song:renoise.Song, arg: any) : any)?
---@field empty (fun(song:renoise.Song, arg:any) : any)?
---@field init Init?
---@field initial any
---@field export (fun(song:renoise.Song, arg:any) : any)?
---@field run Run?
---@field finish Finish?
---@field cancel Cancel?
---@field get_list (fun(c) : any)?
---@field init_palette Init?




---@type fun(type : CommandType, alias : string, name : string, target : string, validate : fun(s : renoise.Song, n : any), options : CommandOptions) : Command
function song_value_command(type, alias, name, target, validate, options)
  local command = new_command(type, alias, name)
  options = options and options or {}

  command.target = target

  command.export = options.export and options.export
    or function(song)
      return get_song_property(song, target)
    end

  command.init = options.init and options.init or function(song)
    return command.export(song)
  end

  command.validate = validate and validate or function(song, arg)
    return arg
  end

  command.empty = options.empty and options.empty or nil

  if command.empty == nil then
    if command.type == CommandType.number then
      command.empty = function(s, initial)
        text_prompt(text_transform(command.name), function(t)
          local n = tonumber(t)
          if n then
            set_song_property(s, target, command.validate(s, n))
          end
        end, initial .. "")
      end
    else
      command.empty = function(s, a) return nil end
    end
  end

  command.run = options.run and options.run
    or function(song, arg, initial)
      -- arg = command.validate(song, arg)
      if arg == nil then
        command.empty(song, command.export(song, initial))
        return nil
      else
        return set_song_property(song, target, command.validate(song, arg))
      end
    end

  command.finish = options.finish and options.finish or function(song, arg)
    return nil
  end

  command.cancel = options.cancel and options.cancel
    or function(song, initial)
      --set_song_property(song, target, command.validate(renoise.song(), initial))
      --don't validate here since we didn't get the value from user input
      --validation here can cause issues, eg, it will add 1 to indicies
      set_song_property(song, target, initial)
    end

  return command
end

---@type fun(alias : string, name : string, target : string, validate : (fun(s : renoise.Song, n : any) : any), options : CommandOptions) : Command
function number_finder_command(alias, name, target, validate, options)
  local command = song_value_command(CommandType.number, alias, name, target, validate, options)

  command.run = (options and options.run) and options.run
    or function(song, arg, initial, recursed)
      if arg == nil then
        if recursed == nil and command.empty then
          command.empty(song, command.export(song, initial))
          return ""
        else
          return "argument is nil"
        end
      else
        local result = set_song_property(song, target, command.validate(song, arg))
        if result then
          return nil
        else
          return "target doesn't exist"
        end
      end
    end

  command.get_list = (options and options.get_list) and options.get_list or function()
    return {}
  end

  command.empty = function(song, initial)
    argument_palette({
      title = command.name,
      get_list = command.get_list,
      base_command = command,
      initial = options.initial and options.initial or initial,
      init = options.init_palette,
    })
  end
  return command
end

---@type fun(alias : string, name : string, finish : Finish, options : CommandOptions?) : Command
function action_command(alias, name, finish, options)
  options = options and options or {}
  local run = options.run and options.run or function(s, n)
    return nil
  end
  local command = new_command(CommandType.action, alias, name, options.init, options.run, finish)
  return command
end

---@type fun(alias : string, name : string, frame : integer) : Command
function middle_show_action(alias, name, frame)
  return action_command(alias, name, function(s, n)
    renoise.app().window.active_middle_frame = frame
  end)
end

---@type fun(alias : string, name : string, options : CommandOptions?) : Command
function action_finder_command(alias, name, options)
  local command = action_command(alias, name, options.finish, options)

  command.finish = options.finish and options.finish
    or function(s, arg, initial)
      -- rprint(command.get_list())
      argument_palette({
        title = command.name,
        get_list = command.get_list,
        base_command = command,
        initial = options.initial and options.initial or 1,
        init = options.init_palette,
      })
    end

  command.run = options.run and options.run or function(song, arg, initial, recursed)
    return ""
  end

  command.get_list = options.get_list and options.get_list
    or function()
      return { { alias = "0", name = "missing get_list function" } }
    end
  return command
end

function string_input_command(alias, name, target, options)
  options = options and options or {}

  options.validate = options.validate and options.validate or function(s, n)
    return n
  end

  local command = song_value_command(CommandType.string, alias, name, target, options.validate, options)
  -- print(alias, name, target)

  command.finish = options.finish and options.finish
    or function(s, arg)
      text_prompt(text_transform(command.name), function(t)
        set_song_property(s, target, t)
      end, get_song_property(s, target))
    end

  command.run = options.run and options.run or function(song, arg, initial, recursed)
    return nil
  end

  return command
end

function number_command(alias, name, target, validate, options)
  return song_value_command(CommandType.number, alias, name, target, validate, options)
end

function toggle_command(alias, name, target)
  return action_command(alias, name, function(s, n)
    set_song_property(s, target, not get_song_property(s, target))
  end
  )
end

function command_call(alias, argument)
  return {
    alias = alias,
    argument = argument,
  }
end
