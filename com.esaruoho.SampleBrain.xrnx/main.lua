-- SampleBrain root main.lua
local Init = require("SampleBrain.Init")

renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:SampleBrain...",
  invoke = Init.show_dialog
}

renoise.tool():add_menu_entry{
  name = "Sample Editor:SampleBrain...",
  invoke = Init.show_dialog
}

renoise.tool():add_keybinding{
  name = "Global:Tools:SampleBrain Dialog...",
  invoke = Init.show_dialog
}
