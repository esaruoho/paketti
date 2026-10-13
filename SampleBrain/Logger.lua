-- REPORT-CARD >> features/samplebrain-diagnostics.feature
-- Append/close every entry so the last checkpoint survives a stalled job.
local Logger = {}
local warned = false
function Logger.path()
  if renoise and renoise.tool then
    return renoise.tool().bundle_path .. "SampleBrain/samplebrain.log"
  end
  return "SampleBrain/samplebrain.log"
end
function Logger.write(message)
  local file, err = io.open(Logger.path(), "a")
  if not file then
    if not warned then
      print("SampleBrain logging unavailable: " .. tostring(err))
      warned = true
    end
    return
  end
  file:write(string.format("[%s cpu=%.3fs memory=%.1fMB] %s\n",
    os.date("%Y-%m-%d %H:%M:%S"), os.clock(), collectgarbage("count") / 1024, tostring(message)))
  file:flush()
  file:close()
end
return Logger
