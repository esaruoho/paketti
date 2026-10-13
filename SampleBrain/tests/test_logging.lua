-- REPORT-CARD >> features/samplebrain-diagnostics.feature
package.path = "?.lua;?/init.lua;" .. package.path
local Logger = require("SampleBrain.Logger")
local file = assert(io.open(Logger.path(), "a")); file:close()
local entries = {}
local original_write = Logger.write
Logger.write = function(message) entries[#entries + 1] = message; original_write(message) end
local callback
local observable = {
  has_notifier = function(_, fn) return callback == fn end,
  add_notifier = function(_, fn) callback = fn end,
  remove_notifier = function() callback = nil end
}
renoise = {tool = function() return {bundle_path = "", app_idle_observable = observable} end}
local JobRunner = require("SampleBrain.jobs.JobRunner")
local completed = false
assert(JobRunner.start(function(job)
  JobRunner.yield(job, 0.5, "diagnostic checkpoint", true)
  return 42
end, nil, function(value) completed = value == 42 end))
callback(); assert(JobRunner.is_running()); callback()
assert(completed and not callback)
local failure
JobRunner.start(function() error("diagnostic test failure") end, nil, nil, function(err) failure = err end)
callback(); assert(failure:find("stack traceback", 1, true))
local cancelled = false
JobRunner.start(function(job) JobRunner.yield(job, 0, "waiting", true) end,
  nil, nil, nil, function() cancelled = true end)
callback(); JobRunner.cancel(); callback()
assert(cancelled and not callback and not JobRunner.is_running())
local text = table.concat(entries, "\n")
for _, marker in ipairs({"started", "diagnostic checkpoint", "complete", "ERROR", "diagnostic test failure", "cancel requested", "cancelled"}) do
  assert(text:find(marker, 1, true), "Missing log event: " .. marker)
end
local log = assert(io.open(Logger.path(), "r")); local saved = log:read("*a"); log:close()
assert(saved:find("diagnostic checkpoint", 1, true))
print("PASS: persisted checkpoints, completion, traceback, cancellation and notifier cleanup")
