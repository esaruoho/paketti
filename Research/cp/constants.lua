---@enum CommandResult
CommandResult = {
  quit = -1,
  continue = 0,
  success = 1,
}
---@enum CommandType
CommandType = {
  number = 1,
  string = 2,
  action = 3,
	custom = 4,
}
---@enum DeviceSubType
DeviceSubType = {
  volume = 1,
  panning = 2,
  pitch = 3,
}
---@enum TextFormat
TextFormat = {
  lowercase = 1,
  capitalized = 2,
  uppercase = 3,
}

function default_prefs()
  return {
    wrapping = true,
    use_mono_font = false,
    spacing = 1,
    width = 320,
    max_results = 12,
    ninja_mode = false,
    schedule_loops_when_playing = true,
    parameter_step_division = 256,
    text_format = TextFormat.lowercase,
    show_tips = true,
    binds = "e:e",
    escape_deletes = true
  }
end
