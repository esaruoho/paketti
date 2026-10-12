-- SampleBrain/persistence/Session.lua
-- Safe session serializer for exporting and restoring SampleBrain configurations without loadfile()

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

--- Load session state safely from a file without loadfile() execution
-- @param filepath string Input file path
-- @return table State table or nil, error
function Session.load(filepath)
  local file, err = io.open(filepath, "r")
  if not file then return nil, err end
  local content = file:read("*a")
  file:close()

  local pos = 1
  local function skip_whitespace()
    while pos <= #content and content:sub(pos, pos):match("[%s,;]") do
      pos = pos + 1
    end
  end

  local parse_value

  local function parse_table()
    local tbl = {}
    pos = pos + 1 -- skip '{'
    while pos <= #content do
      skip_whitespace()
      if pos > #content or content:sub(pos, pos) == "}" then
        pos = pos + 1
        return tbl
      end

      -- parse key
      local key = nil
      if content:sub(pos, pos) == "[" then
        pos = pos + 1
        skip_whitespace()
        if content:sub(pos, pos) == '"' then
          key = content:match('^"([^"]*)"', pos)
          pos = pos + #key + 2
        else
          local num_str = content:match('^(%-?%d+%.?%d*)', pos)
          key = tonumber(num_str)
          if num_str then pos = pos + #num_str end
        end
        skip_whitespace()
        if content:sub(pos, pos) == "]" then pos = pos + 1 end
        skip_whitespace()
        if content:sub(pos, pos) == "=" then pos = pos + 1 end
      end

      skip_whitespace()
      local val = parse_value()
      if key ~= nil then
        tbl[key] = val
      end
    end
    return tbl
  end

  parse_value = function()
    skip_whitespace()
    local char = content:sub(pos, pos)
    if char == "{" then
      return parse_table()
    elseif char == '"' then
      local str = content:match('^"([^"]*)"', pos) or ""
      pos = pos + #str + 2
      return str
    elseif content:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true
    elseif content:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    else
      local num_str = content:match('^(%-?%d+%.?%d*)', pos)
      if num_str then
        pos = pos + #num_str
        return tonumber(num_str)
      end
      pos = pos + 1
      return nil
    end
  end

  local ret_pos = content:find("return%s*%{")
  if ret_pos then
    pos = content:find("%{", ret_pos)
  else
    pos = content:find("%{") or 1
  end

  return parse_value()
end

return Session
