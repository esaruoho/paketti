local separator = package.config:sub(1,1)  -- Gets \ for Windows, / for Unix


--[[
This tool was originally created by danoise,
and somewhat heavily modified by Esa Ruoho a.k.a. Lackluster.
]]--

rns = nil -- reference to renoise.song() 
_trace_filters = nil -- don't show traces in console
--_trace_filters = {".*"}
--_trace_filters = {"^xOscClient"}
-- Only show essential Sononym-related traces, filter out noisy UI/library traces
_trace_filters = {
  "sononym%.db", "%.flac", "%.wav", "%.aiff", -- Show sample file info
  "parsed selection:", "Found filename:", "selectedLocationPath:", -- Show Sononym data
  "Selected Sample Full path:", "Sample loaded:", "Failed to load sample:" -- Show load results
}

-- Set up package path so require() can find cLib modules
local tool_path = renoise.tool().bundle_path
local clib_path = tool_path .. 'Sononymph' .. separator .. 'source' .. separator .. 'cLib' .. separator .. 'classes' .. separator
-- Add cLib classes path to package.path
package.path = package.path .. ";" .. clib_path .. "?.lua"

_clibroot = clib_path

dofile (_clibroot .. 'cLib.lua')
dofile (_clibroot .. 'cDebug.lua')
dofile (_clibroot .. 'cFileMonitor.lua')

---------------------------------------------------------------------------------------------------
-- Sample utility functions (replacement for xLib xSample functions)
---------------------------------------------------------------------------------------------------

-- Get sample buffer if it exists and has sample data
-- @param sample (renoise.Sample)
-- @return renoise.SampleBuffer or nil 
function get_sample_buffer(sample) 
  TRACE("get_sample_buffer(sample)",sample)
  
  if sample.sample_buffer 
    and sample.sample_buffer.has_sample_data
  then
    return sample.sample_buffer
  end
end 

-- Get sample name, as it appears in the sample-list (untitled samples included)
-- @param sample (renoise.Sample)
-- @param sample_idx (number)
-- @return string
function get_display_name(sample,sample_idx)
  TRACE("get_display_name(sample,sample_idx)",sample,sample_idx)
  assert(type(sample)=="Sample")
  assert(type(sample_idx)=="number")
  return (sample.name == "") 
    and ("Sample %02X"):format(sample_idx-1) 
    or sample.name
end

---------------------------------------------------------------------------------------------------
-- Sononymph integration for Paketti
---------------------------------------------------------------------------------------------------


dofile (tool_path .. separator .. 'Sononymph' .. separator .. 'AppUI.lua')
dofile (tool_path .. separator .. 'Sononymph' .. separator .. 'App.lua')

---------------------------------------------------------------------------------------------------
-- local variables & initialization
---------------------------------------------------------------------------------------------------
local TOOL_NAME = "Sononymph"
local TOOL_VERSION = "1.10"

-- Use Paketti preferences directly
local preferences = renoise.tool().preferences

SononymphApp = nil

---------------------------------------------------------------------------------------------------
function SononymphStart(do_show)
  rns = renoise.song()
  if not SononymphApp then 
    SononymphApp = App{
      preferences = preferences,
      tool_name = "Sononymph",
      tool_version = TOOL_VERSION,
      waiting_to_show_dialog = preferences.SononymphAutostart.value
    }
  end
  if do_show then SononymphApp.ui:show() end
end


-- Search Selected Sample function
local function search_selected_sample()
  SononymphStart(true) -- Open dialog
  if SononymphApp and SononymphApp.ui.dialog and SononymphApp.ui.dialog.visible then
    SononymphApp:search_selected_sample()
  end
end

renoise.tool():add_midi_mapping{name="Sononymph:Toggle Sononym Auto-Transfer [Trigger]",invoke=function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end}
renoise.tool():add_midi_mapping{name="Sononymph:Open Sononymph Dialog...", invoke=function() SononymphStart(true) end}
renoise.tool():add_midi_mapping{name="Sononymph:Search Selected Sample in Sononym [Trigger]",invoke=function() search_selected_sample() end}
renoise.tool():add_midi_mapping{name="Sononymph:Load Selected Sample from Sononym (Prompt) [Trigger]",invoke=function(message) if message:is_trigger() then SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end end}
renoise.tool():add_midi_mapping{name="Sononymph:Load Selected Sample from Sononym (No Prompt) [Trigger]",invoke=function(message) if message:is_trigger() then SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end end}

renoise.tool():add_keybinding{name="Global:Sononymph:Toggle Sononym Auto-Transfer [Trigger]", invoke=function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end}
renoise.tool():add_keybinding{name="Global:Sononymph:Open Sononymph Dialog...", invoke=function() SononymphStart(true) end}
renoise.tool():add_keybinding{name="Global:Sononymph:Search Selected Sample in Sononym", invoke=search_selected_sample}
renoise.tool():add_keybinding{name="Global:Sononymph:Load Selected Sample from Sononym (Prompt) [Trigger]", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end}
renoise.tool():add_keybinding{name="Global:Sononymph:Load Selected Sample from Sononym (No Prompt) [Trigger]", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end}

renoise.tool():add_menu_entry{name="Instrument Box:Paketti Gadgets:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Sononymph:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Sononymph:Toggle Sononym Auto-Transfer", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end,selected=function() return SononymphApp and SononymphApp.live_transfer_observable.value or false end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Sononymph:Search Selected Sample in Sononym", invoke = search_selected_sample}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Sononymph:Load Selected Sample from Sononym (Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end}
renoise.tool():add_menu_entry{name="Instrument Box:Paketti:Sononymph:Load Selected Sample from Sononym (No Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end}

renoise.tool():add_menu_entry{name="Sample Editor:Paketti Gadgets:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sononymph:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="--Sample Editor:Paketti:Sononymph:Toggle Sononym Auto-Transfer", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end,selected=function() return SononymphApp and SononymphApp.live_transfer_observable.value or false end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sononymph:Search Selected Sample in Sononym", invoke = search_selected_sample}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sononymph:Load Selected Sample from Sononym (Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end}
renoise.tool():add_menu_entry{name="Sample Editor:Paketti:Sononymph:Load Selected Sample from Sononym (No Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end}

renoise.tool():add_menu_entry{name="Sample Navigator:Paketti Gadgets:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Sononymph:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="--Sample Navigator:Paketti:Sononymph:Toggle Sononym Auto-Transfer", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end,selected=function() return SononymphApp and SononymphApp.live_transfer_observable.value or false end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Sononymph:Search Selected Sample in Sononym", invoke = search_selected_sample}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Sononymph:Load Selected Sample to Selected Slot", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_to_selected_slot() end end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Sononymph:Load Selected Sample from Sononym (Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end}
renoise.tool():add_menu_entry{name="Sample Navigator:Paketti:Sononymph:Load Selected Sample from Sononym (No Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end}

renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti Gadgets:Sononymph Dialog...", invoke = function() SononymphStart(true) end}
renoise.tool():add_menu_entry{name="--Main Menu:Tools:Paketti:Samples:Sononymph:Toggle Sononym Auto-Transfer", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:toggle_live_transfer() end end,selected=function() return SononymphApp and SononymphApp.live_transfer_observable.value or false end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Sononymph:Search Selected Sample in Sononym", invoke = search_selected_sample}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Sononymph:Load Selected Sample from Sononym (Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(true) end end}
renoise.tool():add_menu_entry{name="Main Menu:Tools:Paketti:Samples:Sononymph:Load Selected Sample from Sononym (No Prompt)", invoke = function() SononymphStart(false) if SononymphApp then SononymphApp:load_selected_sample_from_sononym(false) end end}

-- Random sample menu entry (COMMENTED OUT - flip_a_coin function not yet supported by Sononym)
--[[
renoise.tool():add_menu_entry{
  name = "Main Menu:Tools:Sononymph:Random Sample",
  invoke = function()
    SononymphStart(false) -- Initialize app but don't show dialog
    if SononymphApp then
      -- Use the original flip_a_coin function for actual random selection
      flip_a_coin(SononymphApp.preferences.SononymphPathToConfig.value)
    end
  end
}
--]]

-- Load selected sample from Sononym menu entry

-- Random sample keybinding (COMMENTED OUT - flip_a_coin function doesn't work properly)
--[[
renoise.tool():add_keybinding{
  name = "Global:Sononymph:Random Sample [Trigger]", 
  invoke = function()
    SononymphStart(false) -- Initialize app but don't show dialog
    if SononymphApp then
      -- Use the original flip_a_coin function for actual random selection
      flip_a_coin(SononymphApp.preferences.SononymphPathToConfig.value)
    end
  end
}
--]]

---------------------------------------------------------------------------------------------------
-- tool menu entries
function register_tool_menu()
  local str_name = "Main Menu:Tools:Paketti:Samples:Sononymph:Sononymph..."
  local str_name_active = "Main Menu:Tools:Paketti:Samples:Sononymph:Sononymph (active)..."

  if renoise.tool():has_menu_entry(str_name) then
    renoise.tool():remove_menu_entry(str_name)
  elseif renoise.tool():has_menu_entry(str_name_active) then
    renoise.tool():remove_menu_entry(str_name_active)
  end
  renoise.tool():add_menu_entry{
    name = (SononymphApp and SononymphApp.monitor_active) and str_name_active or str_name,
    invoke = function() SononymphStart(true) end}
end

register_tool_menu()    
---------------------------------------------------------------------------------------------------
-- notifications
---------------------------------------------------------------------------------------------------
renoise.tool().app_new_document_observable:add_notifier(function()
  TRACE("main app_new_document_observable fired...")
  SononymphStart(preferences.SononymphAutostart.value) end) 
  