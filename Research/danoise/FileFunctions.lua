local path = "/Users/Bjørn/Docum\\ents/Renoise//User Library/\/Effect Chains/"
--local path = "C:/Users/Bjørn/Documents/Renoise//User Library//Effect Chains/Examples.xrnd"
local patt = "(.-)([^\\/]-%.?([^%.\\/]*))$"
--local patt = "(.-)([^\\]-([^%.]+))$"

local path,file,ext = string.match(path,patt)

print("path",path)
print("file",file)
print("ext",ext)






