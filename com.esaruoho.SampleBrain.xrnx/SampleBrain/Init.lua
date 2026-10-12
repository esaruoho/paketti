-- SampleBrain/Init.lua
-- Main initialization module for SampleBrain

local MainDialog = require("SampleBrain.ui.MainDialog")

local Init = {}

function Init.show_dialog()
  MainDialog.show()
end

if renoise and renoise.tool then
  renoise.tool().app_new_document_observable:add_notifier(function()
    MainDialog.reset_state()
  end)
end

return Init
