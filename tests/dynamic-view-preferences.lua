-- Regression: loader pre-populates this global with a DocumentList.
local loads = 0
local old_list = setmetatable({}, {__index = function()
  error("No matching overload found: DocumentList requires an integer index")
end})
DynamicViewPrefs = old_list
renoise = {
  ApplicationWindow = {},
  tool = function() return {bundle_path = "./"} end,
  Document = {
    ObservableNumber = function(value) return {value = value} end,
    create = function() return function()
      local props = {}
      local doc = {}
      function doc:add_property(name, value) props[name] = value end
      function doc:property(name) return props[name] end
      function doc:load_from(path)
        assert(path == "./preferencesDynamicView.xml")
        loads = loads + 1
        props.dynamic_view01_middle_step1.value = 6
      end
      setmetatable(doc, {__index = props})
      return doc
    end end
  }
}
io.exists = function() return true end
local file = assert(io.open("PakettiDynamicViews.lua"))
local source = file:read("*a")
file:close()
-- Run the actual initialization, stopping before UI/action registration.
local boundary = assert(source:find("-- Function to check if the middle frame", 1, true))
local initialize = assert(load(source:sub(1, boundary - 1)))
initialize()
assert(DynamicViewPrefs ~= old_list)
assert(loads == 1)
assert(DynamicViewPrefs.dynamic_view01_middle_step1.value == 6)
assert(DynamicViewPrefs.dynamic_view09_play_step8.value == 1)
-- Reloading initializes an independent document and restores saved settings.
initialize()
assert(loads == 2)
assert(DynamicViewPrefs.dynamic_view01_middle_step1.value == 6)
-- Missing XML keeps defaults.
io.exists = function() return false end
initialize()
assert(loads == 2)
assert(DynamicViewPrefs.dynamic_view01_middle_step1.value == 1)
print("Dynamic View preferences regression passed")
