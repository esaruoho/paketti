-- SampleBrain/jobs/JobRunner.lua
-- Cooperative multitasking for heavy DSP operations in Renoise

local JobRunner = {}

local current_job = nil

local function idle_handler()
  if not current_job then
    if renoise and renoise.tool and renoise.tool().app_idle_observable:has_notifier(idle_handler) then
      renoise.tool().app_idle_observable:remove_notifier(idle_handler)
    end
    return
  end

  if current_job.cancelled then
    local finished_job = current_job
    current_job = nil
    if renoise and renoise.tool and renoise.tool().app_idle_observable:has_notifier(idle_handler) then
      renoise.tool().app_idle_observable:remove_notifier(idle_handler)
    end
    if finished_job.on_cancel then
      finished_job.on_cancel()
    end
    return
  end

  -- Record start time for time-budgeted yields
  current_job.last_yield_time = os.clock()

  local status, err = coroutine.resume(current_job.co, current_job)

  if coroutine.status(current_job.co) == "dead" then
    local finished_job = current_job
    current_job = nil
    if renoise and renoise.tool and renoise.tool().app_idle_observable:has_notifier(idle_handler) then
      renoise.tool().app_idle_observable:remove_notifier(idle_handler)
    end

    if status then
      if finished_job.on_complete then
        finished_job.on_complete(err)
      end
    else
      if finished_job.on_error then
        finished_job.on_error(err)
      else
        if renoise and renoise.app then
          renoise.app():show_error("SampleBrain Job Error:\n" .. tostring(err))
        else
          print("SampleBrain Job Error:\n" .. tostring(err))
        end
      end
    end
  end
end

--- Start a cooperative job
-- @param func function Coroutine body `function(job)`
-- @param on_progress function Callback for progress updates `function(percent, message)`
-- @param on_complete function Callback when finished `function(result)`
-- @param on_error function Callback on error `function(err)`
-- @param on_cancel function (Optional) Callback on cancellation `function()`
-- @return boolean true if started successfully
function JobRunner.start(func, on_progress, on_complete, on_error, on_cancel)
  if current_job then
    return false, "A job is already running."
  end

  current_job = {
    co = coroutine.create(func),
    on_progress = on_progress,
    on_complete = on_complete,
    on_error = on_error,
    on_cancel = on_cancel,
    cancelled = false,
    last_yield_time = os.clock()
  }

  if renoise and renoise.tool then
    if not renoise.tool().app_idle_observable:has_notifier(idle_handler) then
      renoise.tool().app_idle_observable:add_notifier(idle_handler)
    end
  else
    -- If no Renoise, run synchronously for tests
    while current_job do
      idle_handler()
    end
  end

  return true
end

--- Cancel the currently running job
function JobRunner.cancel()
  if current_job then
    current_job.cancelled = true
    -- We do NOT set current_job = nil here. 
    -- The next idle_handler execution will notice current_job.cancelled == true, 
    -- fire on_cancel(), and properly deregister the idle_handler.
  end
end

--- Check if a job is currently running
function JobRunner.is_running()
  return current_job ~= nil
end

--- Yield from within a job coroutine, optionally updating progress
-- Yielding happens only if forced or if the CPU time budget (e.g., 10ms) is exceeded.
-- @param job table The job instance passed to the coroutine
-- @param percent number 0.0 to 1.0 progress
-- @param message string Optional status message
-- @param force boolean If true, yield regardless of elapsed time
function JobRunner.yield(job, percent, message, force)
  if job.cancelled then
    coroutine.yield()
  end
  
  -- Use ~10ms CPU budget limit
  local elapsed = os.clock() - job.last_yield_time
  if force or elapsed > 0.010 then
    if job.on_progress and percent then
      job.on_progress(percent, message)
    end
    coroutine.yield()
    job.last_yield_time = os.clock() -- Reset timer after waking back up
  end
end

return JobRunner
