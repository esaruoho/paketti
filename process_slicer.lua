--[[============================================================================
process_slicer.lua
============================================================================]]--

--[[
ProcessSlicer for Paketti - allows slicing up long-running operations into smaller chunks
to maintain UI responsiveness and show progress.

Main benefits:
- Shows current progress of operations
- Allows users to abort operations
- Prevents Renoise from thinking the script is frozen
- Maintains UI responsiveness during heavy operations
]]

class "ProcessSlicer"

function ProcessSlicer:__init(process_func, ...)
  assert(type(process_func) == "function", 
    "Expected a function as first argument")

  self.__process_func = process_func
  self.__process_func_args = {...}
  self.__process_thread = nil
  self.__cancelled = false
end

--------------------------------------------------------------------------------
-- Returns true when the current process is running

function ProcessSlicer:running()
  return (self.__process_thread ~= nil)
end

--------------------------------------------------------------------------------
-- Start a process

function ProcessSlicer:start()
  assert(not self:running(), "Process already running")
  
  self.__process_thread = coroutine.create(self.__process_func)
  
  renoise.tool().app_idle_observable:add_notifier(
    ProcessSlicer.__on_idle, self)
end

--------------------------------------------------------------------------------
-- Stop a running process

function ProcessSlicer:stop()
  assert(self:running(), "Process not running")

  renoise.tool().app_idle_observable:remove_notifier(
    ProcessSlicer.__on_idle, self)

  self.__process_thread = nil
end

--------------------------------------------------------------------------------
-- Cancel the process

function ProcessSlicer:cancel()
  self.__cancelled = true
end

--------------------------------------------------------------------------------
-- Check if process was cancelled

function ProcessSlicer:was_cancelled()
  return self.__cancelled
end

--------------------------------------------------------------------------------
-- Internal function called during idle to continue processing

function ProcessSlicer:__on_idle()
  assert(self.__process_thread ~= nil, "ProcessSlicer internal error: " ..
    "Expected no idle call with no thread running")
  
  -- Continue or start the process while it's still active
  if (coroutine.status(self.__process_thread) == 'suspended') then
    local succeeded, error_message = coroutine.resume(
      self.__process_thread, unpack(self.__process_func_args))
    
    if (not succeeded) then
      -- Stop the process on errors
      self:stop()
      -- Forward the error
      error(error_message) 
    end
    
  -- Stop when the process function completed
  elseif (coroutine.status(self.__process_thread) == 'dead') then
    self:stop()
  end
end

-- Helper function to create a progress dialog
function ProcessSlicer:create_dialog(title)
  local vb = renoise.ViewBuilder()
  local dialog = nil
  
  local DEFAULT_MARGIN = renoise.ViewBuilder.DEFAULT_CONTROL_MARGIN
  local DEFAULT_SPACING = renoise.ViewBuilder.DEFAULT_CONTROL_SPACING
  
  local dialog_content = vb:column {
    margin = DEFAULT_MARGIN,
    spacing = DEFAULT_SPACING,
    
    vb:text {
      id = "progress_text",
      text = "Processing..."
    },
    
    vb:button {
      id = "cancel_button",
      text = "Cancel",
      width = 80,
      notifier = function()
        self:cancel()
        if dialog and dialog.visible then
          dialog:close()
        end
      end
    }
  }
  
  dialog = renoise.app():show_custom_dialog(
    title or "Processing...", dialog_content)
    
  return dialog, vb
end 