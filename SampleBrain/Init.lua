-- SampleBrain/Init.lua
-- Main initialization module for SampleBrain

local MainDialog = require("SampleBrain.ui.MainDialog")

local Init = {}

function Init.show_dialog()
  MainDialog.show()
end

return Init
