-- Run with lua tests/disk-browser-auto-toggle.lua from the tool directory.
local handler
local saved = 0
local window = {disk_browser_is_visible=true}
preferences = {paketti_auto_disk_browser_mode={value=0}, save_as=function(_, path)
  assert(path == "preferences.xml")
  saved = saved + 1
end}
renoise = {
  app=function() return {window=window, show_status=function() end} end,
  tool=function() return {
    app_new_document_observable={has_notifier=function() return false end,
      add_notifier=function(_, fn) handler=fn end},
    add_keybinding=function() end, add_midi_mapping=function() end
  } end
}
local file = assert(io.open("PakettiForeignSnippets.lua"))
local source = file:read("*a"); file:close()
local boundary = assert(source:find("-- Paketti Loop Block Transport Control", 1, true))
assert(load(source:sub(1, boundary-1)))()
assert(pakettiAutoHideDiskBrowserIsEnabled() == false, "mode 0 must be unchecked")
for _, mode in ipairs({1, 2}) do
  preferences.paketti_auto_disk_browser_mode.value = mode
  assert(pakettiAutoHideDiskBrowserIsEnabled() == true)
  handler()
  assert(window.disk_browser_is_visible == (mode == 2), "song load must apply mode")
  pakettiAutoHideDiskBrowserToggle()
  assert(preferences.paketti_auto_disk_browser_mode.value == 0, "checked toggle must turn off")
  window.disk_browser_is_visible = mode == 1
  handler()
  assert(window.disk_browser_is_visible == (mode == 1), "off must leave visibility alone")
end
pakettiAutoHideDiskBrowserToggle()
assert(preferences.paketti_auto_disk_browser_mode.value == 1)
assert(pakettiAutoHideDiskBrowserGetModeName() == "Hide on Song Load")
assert(saved == 3, "every toggle must save")
print("Disk Browser toggle regression checks passed")
