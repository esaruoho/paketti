-- tools for streaming base64 into sample data and reverse

-- pack and unpack 32bit float from/to whole integer numbers representing ieee 754 f 32bit numbers

--funcwrap

local abs = math.abs
local pow = math.pow
local log = math.log
local floor = math.floor
local ceil = math.ceil
local huge = math.huge
local nan = math.nan

--constants

local signbit = 2147483648.0
local opsignbit = 1.0/2147483648.0
local expbit = 8388608.0
local opexpbit = 1.0/8388608.0

local dnexp = pow(2.0,-126.0)
local opdnexp = 1.0/pow(2.0,-126.0)

local oplog2 = 1.0/log(2.0)

--seems OK, but different (decimal) values come out as doubles?
function unpackfloat(x)
  local sgn = floor(x*opsignbit) == 1.0 and -1.0 or 1.0
  x = x - signbit*(sgn*-0.5+0.5)
  local exp = floor(x*opexpbit)
  local mant = (x-exp*expbit)
  if exp == 0.0 then
    -- denormal
    -- return 0.0 -- throw away denormals
    return sgn*(mant*opexpbit)*dnexp
  end
  if exp == 255.0 then
    -- infinity/nan
    if mant == 0.0 then return huge*sgn
    else return nan
    end
  end
  local base = pow(2.0, exp-127.0)
  return sgn*((1.0+mant*opexpbit)*base)
end

--tested: seems OK
function packfloat(x)
  local y = abs(x)
  local sgn = y == x and 0.0 or signbit
  local exp = floor( log(y)*oplog2 )
  --overflow of 32bit float = inf
  if exp > 127.0 then return 2139095040.0 + sgn; end
  --denormal
  -- if exp < -126.0 then return sgn -- throw away denormals
  if exp < -126.0 then return sgn + floor(y*expbit*opdnexp); end
  local base= pow(2.0,exp)
  return sgn+(exp+127.0)*expbit+floor((y-base)/base*expbit)
end


--base64 lookup tables

local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

b64enctable = {}
b64dectable = {}


-- build tables

for i=0, 63, 1 do
  b64enctable[i] = b64chars:sub(i+1,i+1)
  b64dectable[b64chars:byte(i+1)] = i
end

-- parse a string of sample data

   
local b64bytes = {

-- 0,         0,
 4,      1/16,
16,       1/4,
64,         1

}

-- mod each pre with 256, chop each curr fracts

--TODO: combine byte and sample/string generation + direct streaming from/to renoise sample?

function parseb64(input)
  local results = {}
  
  local chars = input:len()
  
  local last = 0
  local bits = 0
  local bytes = {}
  local bytecnt = 0
  
  for i=1,#input,1 do
    local val = b64dectable[input:byte(i)]
    if val == nil then break; end
    bits = bits + 6
    if bits > 7 then
      bytecnt = bytecnt%3 + 1
      bytes[#bytes+1] = (last*b64bytes[bytecnt*2-1])%256 + floor(val*b64bytes[bytecnt*2])
      bits = bits - 8
    end
    last = val
  end
  for i=1,#bytes,4 do
    results[#results+1] = unpackfloat( bytes[i] + bytes[i+1]*256 + bytes[i+2]*65536 + bytes[i+3]*16777216) * 2 -- convolver halves amplitude
  end
  return results
end

--[[

     a)       b)       c)      d)
     A        P        7       /         P       g
  000000   00.1111  1110.11  111111 . 001111  100000

     A        P1       7       /       P2      g
  000000   00.1111  1110.11  111111 . 001111  10. (0000)     -> OK

--> into this value: 

 P2      g   7    /       P1   7        A   P1
             c    d       b    c        a   b
001111.10. | 11.111111 | 1111.1110 | 000000.00
seeeeeeee    mm mmmmmm   mmmm mmmm   mmmmmm mm
    4            3           2           1

--]]

local b64chars = {

--a,               b,
--b,               c,
--c,               d,
--x,               x

--tocurr-floor    --toaccum-mod

 1/4,              16,    --byte1
1/16,               4,    --byte2
1/64,               1,    --byte3
   0,               0,    --dummy to accumulate

}

function renderb64(inputs)
  local result = {}
  
  local bytes = {}
--genereate byte chain
  for i=1,#inputs,1 do
    local val = inputs[i]
    if val == nil then break; end
    val = packfloat(val*0.5) --convolver halves amplitude
    bytes[#bytes+1] = floor(val)%256
    bytes[#bytes+1] = floor(val/256) %256 
    bytes[#bytes+1] = floor(val/65536) %256 
    bytes[#bytes+1] = floor(val/16777216) %256 
  end
--pack chain into char table
  local nchars = #bytes*4/3
  local charsnum = ceil(nchars)
  local neq = floor((nchars-floor(nchars))*3+0.1)
  if neq == 1 then neq = 2
  elseif neq == 2 then neq = 1
  end
  local accum = 0
  local bytecnt = 1
  local bits = 0
  for i=1, charsnum, 1 do
    local val = 0
    if bits < 6 then
      val = bytes[bytecnt]
      bytecnt = bytecnt + 1
      val = val == nil and 0 or val
      bits = bits + 8
    end
--    result[#result+1] = b64enctable[(val*b64chars[tidx*2]%64)+accum]
    local tidx = (i-1)%4 + 1
    result[#result+1] = b64enctable[floor(val*b64chars[tidx*2-1])+accum] 
    accum = (val*b64chars[tidx*2])%64
    bits = bits - 6
  end
  --add equality signs indicating empty bits at the end (2 bits for each sign)
  for i=1,neq do result[#result+1] = "="; end
  return table.concat(result) -- convert to string
end
    
local b64f = {}
b64f.parse = parseb64
b64f.render = renderb64
return b64f

