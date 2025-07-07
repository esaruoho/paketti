
local instr = renoise.song().selected_instrument
--oprint(instr)

local get_comment = function(instr)
  return table.concat(instr.comments,"\n")
end

local set_comment = function(instr,tbl)
  instr.comments = tbl
end

--print("get_comment:",get_comment(instr))

local new_comment = {
  "This is an approximation of the 808 drum machine, ",
  "made with samples from the factory content"
}
print("set_comment:",set_comment(instr,new_comment))
print("get_comment:",get_comment(instr))

local get_tags = function(instr)
  return table.concat(instr.tags,"\n")
end

local set_tags = function(instr,tbl)
  instr.tags = tbl
end

local new_tags = {
  "Foo",
  "Bar",
  "xOx"
}
print("set_tags:",set_tags(instr,new_tags))
print("get_tags:",get_tags(instr))


