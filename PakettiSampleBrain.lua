-- PakettiSampleBrain.lua
-- SampleBrain for Renoise integration into Paketti

local SampleBrain = require("SampleBrain.Init")

function pakettiSampleBrainShow()
  SampleBrain.show_dialog()
end

-- Menu entries
PakettiAddMenuEntry{
  name = "Main Menu:Tools:Paketti:SampleBrain...",
  invoke = pakettiSampleBrainShow
}

PakettiAddMenuEntry{
  name = "Sample Editor:Paketti:SampleBrain...",
  invoke = pakettiSampleBrainShow
}

PakettiAddMenuEntry{
  name = "Instrument Box:Paketti:SampleBrain...",
  invoke = pakettiSampleBrainShow
}

-- Keybinding
renoise.tool():add_keybinding{
  name = "Global:Paketti:SampleBrain Dialog...",
  invoke = pakettiSampleBrainShow
}
