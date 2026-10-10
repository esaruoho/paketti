-- SampleBrain/persistence/Session.lua
-- Session serializer for exporting and restoring SampleBrain configurations

local Session = {}

--- Save session state to a file
-- @param filepath string Output file path
-- @param state_table table Session state table
-- @return boolean true if successful
function Session.save(filepath, state_table)
  local file, err = io.open(filepath, "w")
  if not file then return false, err end

  local function serialize(tbl, indent)
    indent = indent or ""
    local str = "{\n"
    for k, v in pairs(tbl) do
      local key_str = (type(k) == "number") and string.format("[%d]", k) or string.format("[%q]", k)
      if type(v) == "table" then
        str = str .. indent .. "  " .. key_str .. " = " .. serialize(v, indent .. "  ") .. ",\n"
      elseif type(v) == "string" then
        str = str .. indent .. "  " .. key_str .. " = " .. string.format("%q", v) .. ",\n"
      elseif type(v) == "number" or type(v) == "boolean" then
        str = str .. indent .. "  " .. key_str .. " = " .. tostring(v) .. ",\n"
      end
    end
    return str .. indent .. "}"
  end

  local content = "return " .. serialize(state_table) .. "\n"
  file:write(content)
  file:close()
  return true
end

--- Load session state from a file
-- @param filepath string Input file path
-- @return table State table or nil, error
function Session.load(filepath)
  local func, err = loadfile(filepath)
  if not func then return nil, err end

  local ok, res = pcall(func)
  if not ok then return nil, res end

  return res
end

return Session
